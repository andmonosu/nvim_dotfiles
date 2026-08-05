local home = os.getenv("HOME")
-- Buscamos dinámicamente el binario del LSP instalado por Nix en tu PATH
local jdtls_bin = vim.fn.exepath("jdtls")

if jdtls_bin == "" then
	vim.notify(
		"JDTLS no se encontró en el PATH. Asegúrate de que está instalado en Home Manager.",
		vim.log.levels.WARN
	)
	return
end

-- 1. Detectar el nombre del proyecto actual para crear un espacio de trabajo aislado
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = home .. "/.cache/jdtls/workspace/" .. project_name

-- Carpeta escribible en tu HOME para la configuración del usuario
local user_config_dir = home .. "/.cache/jdtls/config"

local lombok_jar = vim.fn.expand("~/.local/share/nvim/lombok/share/java/lombok.jar")

-- Verificación simple de lectura
if vim.fn.filereadable(lombok_jar) ~= 1 then
	vim.notify("⚠️ JDTLS: El enlace de Lombok en xdg.dataFile no es accesible", vim.log.levels.WARN)
end

-- [FIX 1] Único bloque para localizar el jar del java-debug-adapter.
-- Tu instalación NO usa Mason (usas xdg.dataFile de Home Manager), así que
-- symlinkeas directamente el paquete vscjava.vscode-java-debug de Nix bajo
-- mason/packages/java-debug-adapter/share/vscode/extensions/... (confirmado
-- con find -L). Se elimina el segundo bloque duplicado que usaba la ruta
-- inexistente "/extension/server/..." y que disparaba el warning en falso.
local java_debug_jar_pattern = home
	.. "/.local/share/nvim/mason/packages/java-debug-adapter/share/vscode/extensions/vscjava.vscode-java-debug/server/com.microsoft.java.debug.plugin-*.jar"
local bundles = vim.fn.glob(java_debug_jar_pattern, 1, 1) -- devuelve tabla directamente (sin split manual)

if #bundles == 0 then
	vim.notify(
		"No se encontró el JAR del Debugger de Java. La depuración no estará disponible.",
		vim.log.levels.WARN
	)
end

-- 2. Encontrar la ruta real del paquete de Nix para extraer el launcher y la plantilla de config
local jdtls_real_path = vim.fn.resolve(jdtls_bin)
local jdtls_dir = vim.fn.fnamemodify(jdtls_real_path, ":h")

-- Buscamos el jar del launcher de Equinox en el directorio de instalación de Nix
local launcher_jar = vim.fn.glob(jdtls_dir .. "/../share/java/jdtls/plugins/org.eclipse.equinox.launcher_*.jar")
if launcher_jar == "" then
	-- Fallback común en algunas distribuciones de Nixpkgs
	launcher_jar = vim.fn.glob(jdtls_dir .. "/../plugins/org.eclipse.equinox.launcher_*.jar")
end

-- Buscamos la plantilla de configuración original (que es de solo lectura) en Nix
local nix_config_dir = jdtls_dir .. "/../share/java/jdtls/config_linux"
if vim.fn.isdirectory(nix_config_dir) == 0 then
	nix_config_dir = jdtls_dir .. "/../config_linux"
end

-- [FIX 3] Resolvemos dinámicamente el JAVA_HOME real a partir del "java" del
-- PATH (igual que hacemos con jdtls), en vez de depender de que el sistema
-- lo adivine. Sin esto, JDTLS no puede resolver el ejecutable java al
-- lanzar tests o sesiones de debug (error "Could not resolve java executable").
local java_bin = vim.fn.exepath("java")
local java_home = ""
if java_bin ~= "" then
	-- .../openjdk-XX/lib/openjdk/bin/java -> subimos 2 niveles hasta .../lib/openjdk
	-- Usamos la ruta RESUELTA solo para java_home (necesitamos el árbol real
	-- del JDK para settings.java.configuration.runtimes), pero para el
	-- ejecutable que se persiste en launch.json usamos java_bin SIN resolver
	-- (ver más abajo) porque ese symlink de perfil de Nix se mantiene
	-- estable entre rebuilds, mientras que la ruta resuelta al store
	-- caduca en cuanto haces GC de generaciones antiguas.
	java_home = vim.fn.fnamemodify(vim.fn.resolve(java_bin), ":h:h")
else
	vim.notify("No se encontró 'java' en el PATH. JDTLS podría no poder ejecutar/depurar.", vim.log.levels.WARN)
end

local on_attach = function(client, bufnr)
	-- 1. Inicializar nvim-dap con JDTLS
	require("jdtls").setup_dap({ hotcodereplace = "auto" })

	-- [FIX 2] Sin esto, dap.continue() no tiene ninguna configuración de tipo
	-- "Launch" para clases con main() y termina intentando resolver (mal)
	-- lo que sea que tengas abierto en el buffer, sea o no ejecutable
	-- (por eso salía el error al intentar depurar ClientMapper).
	require("jdtls.dap").setup_dap_main_class_configs()

	-- [FIX 5] setup_dap_main_class_configs() SOBREESCRIBE por completo
	-- dap.configurations.java cada vez que se ejecuta (no añade, reemplaza).
	-- Como on_attach se dispara en cada buffer Java que abres, cambiar a otro
	-- archivo después de generar el launch.json de Attach lo borraba. Lo
	-- re-fusionamos aquí siempre que el archivo ya exista, para que sobreviva.
	do
		local root_dir_attach = client.config.root_dir or vim.fn.getcwd()
		local launch_json_path_attach = root_dir_attach .. "/.vscode/launch.json"
		if vim.fn.filereadable(launch_json_path_attach) == 1 then
			-- Mismo chequeo de auto-sanación que FIX 9: si el javaExec ya no
			-- existe, no lo fusionamos (evita registrar una config muerta).
			local ok_read, content = pcall(vim.fn.readfile, launch_json_path_attach)
			local stale = false
			if ok_read then
				local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(content, "\n"))
				if ok_decode and decoded and decoded.configurations then
					for _, cfg in ipairs(decoded.configurations) do
						if cfg.javaExec and vim.fn.filereadable(cfg.javaExec) ~= 1 then
							stale = true
							break
						end
					end
				end
			end
			if not stale then
				require("dap.ext.vscode").load_launchjs(launch_json_path_attach, { java = { "java" } })
			end
		end
	end

	-- Helper exclusivo de atajos locales del buffer de Java
	local bufmap = function(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
	end

	-- ==========================================
	-- 🤖 FUNCIÓN: Autogenerar .vscode/launch.json en modo ATTACH (solo Spring)
	-- ==========================================
	local function auto_generate_launch_json()
		local root_dir = client.config.root_dir or vim.fn.getcwd()
		local vscode_dir = root_dir .. "/.vscode"
		local launch_json_path = vscode_dir .. "/launch.json"

		-- [FIX 9] Auto-sanación: si el launch.json existe pero el javaExec
		-- que contiene ya no es legible (p.ej. ruta de Nix caducada tras un
		-- rebuild/GC, o launch.json generado antes de FIX 8), lo borramos
		-- para que se regenere limpio en vez de fusionar una config muerta.
		if vim.fn.filereadable(launch_json_path) == 1 then
			local ok_read, content = pcall(vim.fn.readfile, launch_json_path)
			if ok_read then
				local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(content, "\n"))
				if ok_decode and decoded and decoded.configurations then
					for _, cfg in ipairs(decoded.configurations) do
						if cfg.javaExec and vim.fn.filereadable(cfg.javaExec) ~= 1 then
							vim.notify(
								"♻️  javaExec obsoleto en launch.json (probable rebuild de Nix), regenerando...",
								vim.log.levels.INFO
							)
							vim.fn.delete(launch_json_path)
							break
						end
					end
				end
			end
		end

		-- [FIX 4] La carga automática "on-demand" de nvim-dap SOLO se activa
		-- si dap.configurations.java está vacío. Como setup_dap_main_class_configs()
		-- ya lo rellena con las configs de tipo Launch, el launch.json (Attach)
		-- nunca se fusiona solo. Por eso, si ya existe, lo cargamos a mano.
		if vim.fn.filereadable(launch_json_path) == 1 then
			require("dap.ext.vscode").load_launchjs(launch_json_path, { java = { "java" } })
			return
		end

		-- Buscamos el archivo que contiene la anotación de Spring
		local search_cmd = 'grep -l -r "@SpringBootApplication" ' .. root_dir .. "/src/ 2>/dev/null"
		local handle = io.popen(search_cmd)
		if not handle then
			return
		end
		local result = handle:read("*l")
		handle:close()

		if result and result ~= "" then
			local class_name = ""
			local package_name = ""
			for line in io.lines(result) do
				local c = line:match("^public%s+class%s+(%w+)")
				if c then
					class_name = c
				end
				local p = line:match("^package%s+([%w%.]+)%s*;")
				if p then
					package_name = p
				end
				if class_name ~= "" and package_name ~= "" then
					break
				end
			end

			if class_name ~= "" then
				-- [FIX 7] Usamos el projectName EXACTO que JDTLS ya conoce
				-- (tomado de una config Launch ya generada por
				-- setup_dap_main_class_configs()), en vez de derivarlo del
				-- nombre de la carpeta. JDTLS conoce el proyecto por su
				-- artifactId/nombre interno (p.ej. "tacos-online"), que no
				-- tiene por qué coincidir con el nombre de la carpeta
				-- ("Tacos-Online"), y una discrepancia aquí hace fallar la
				-- resolución del ejecutable aunque javaExec esté presente.
				local proj_name = nil
				local ok_dap, dap_mod = pcall(require, "dap")
				if ok_dap and dap_mod.configurations.java then
					for _, cfg in ipairs(dap_mod.configurations.java) do
						if cfg.request == "launch" and cfg.projectName then
							proj_name = cfg.projectName
							break
						end
					end
				end
				proj_name = proj_name or vim.fn.fnamemodify(root_dir, ":t")

				local fqn = package_name ~= "" and (package_name .. "." .. class_name) or class_name

				-- [FIX 6] mainClass y javaExec explícitos: sin ellos, el
				-- adaptador de nvim-jdtls intenta "adivinar" el ejecutable
				-- Java también para el Attach (aunque semánticamente no
				-- debería necesitarlo) y falla al no tener de dónde sacarlo.
				local launch_content = {
					version = "0.2.0",
					configurations = {
						{
							type = "java",
							name = "Spring Boot: Attach to " .. class_name,
							request = "attach",
							hostName = "localhost",
							port = 5005,
							projectName = proj_name,
							mainClass = fqn,
							-- [FIX 8] Usamos java_bin (symlink de perfil SIN
							-- resolver) en vez de java_home .. "/bin/java"
							-- (ruta resuelta al store) para que esta ruta
							-- persistida en disco no quede obsoleta con
							-- futuros rebuilds/GC de Nix.
							javaExec = java_bin ~= "" and java_bin or nil,
						},
					},
				}

				vim.fn.mkdir(vscode_dir, "p")
				local f = io.open(launch_json_path, "w")
				if f then
					f:write(vim.fn.json_encode(launch_content))
					f:close()
					print("✨ .vscode/launch.json (Attach) generado para: " .. class_name)
					require("dap.ext.vscode").load_launchjs(launch_json_path, { java = { "java" } })
				end
			end
		end
	end

	-- ==========================================
	-- GRUPO: [D]ebug (<leader>d...)
	-- ==========================================
	bufmap("n", "<leader>dc", function()
		auto_generate_launch_json()
		require("dap").continue()
	end, "DAP: Continuar / Iniciar")

	bufmap("n", "<leader>do", function()
		require("dap").step_over()
	end, "DAP: Paso sobre (Step Over)")
	bufmap("n", "<leader>di", function()
		require("dap").step_into()
	end, "DAP: Paso dentro (Step Into)")
	bufmap("n", "<leader>db", function()
		require("dap").toggle_breakpoint()
	end, "DAP: Alternar Breakpoint")
	bufmap("n", "<leader>dq", function()
		require("dap").terminate()
	end, "DAP: Detener Sesión")

	-- ==========================================
	-- GRUPO: [J]ava (<leader>j...)
	-- ==========================================
	bufmap("n", "<leader>ju", "<cmd>JdtUpdateConfig<CR>", "Java: Actualizar Configuración")
	bufmap("n", "<leader>jo", function()
		require("jdtls").organize_imports()
	end, "Java: Organizar Imports")
	bufmap("n", "<leader>jv", function()
		require("jdtls").extract_variable()
	end, "Java: Extraer Variable")
	bufmap("n", "<leader>jC", function()
		require("jdtls").extract_constant()
	end, "Java: Extraer Constante")
	bufmap("n", "<leader>jm", function()
		require("jdtls").extract_method()
	end, "Java: Extraer Metodo")

	-- 🧪 Suite de Testing (JUnit)
	bufmap("n", "<leader>jt", function()
		require("jdtls").test_nearest_method()
	end, "Java: Ejecutar Test actual (JUnit)")
	bufmap("n", "<leader>jT", function()
		require("jdtls").test_class()
	end, "Java: Ejecutar todos los Tests de la clase")
	bufmap("n", "<leader>jr", function()
		require("jdtls").pick_test()
	end, "Java: Ver historial/reporte de Tests")

	-- 📁 Creación de archivos
	bufmap("n", "<leader>jc", function()
		require("springboot-nvim").generate_class()
	end, "Java: Crear Clase")
	bufmap("n", "<leader>ji", function()
		require("springboot-nvim").generate_interface()
	end, "Java: Crear Interfaz")
	bufmap("n", "<leader>je", function()
		require("springboot-nvim").generate_enum()
	end, "Java: Crear Enum")

	-- ==========================================
	-- 🍃 GRUPO DINÁMICO: [S]pring Boot (<leader>s...)
	-- ==========================================
	local is_spring_project = false
	local root_dir = client.config.root_dir or vim.fn.getcwd()

	local function check_spring(filename)
		local f = io.open(root_dir .. "/" .. filename, "r")
		if f then
			local content = f:read("*all")
			f:close()
			return string.find(content, "spring") ~= nil
		end
		return false
	end

	if check_spring("pom.xml") or check_spring("build.gradle") then
		is_spring_project = true
	end

	if is_spring_project then
		-- 🚀 MODO RUN: Ejecución normal
		bufmap("n", "<leader>sr", function()
			require("springboot-nvim").boot_run()
		end, "Spring: Arrancar aplicación (Run Mode)")

		-- 🪲 MODO DEBUG: Abre puertos de depuración en el 5005
		bufmap("n", "<leader>sd", function()
			local debug_args =
				"-Dspring-boot.run.jvmArguments='-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005'"
			print("🍃 Levantando Spring Boot en Modo Depuración (Puerto 5005)...")
			require("springboot-nvim").boot_run(debug_args)
		end, "Spring: Arrancar en Modo Depuración (Debug Mode)")
	end

	-- Formatear automáticamente al guardar
	vim.api.nvim_create_autocmd("BufWritePre", {
		buffer = bufnr,
		callback = function()
			vim.lsp.buf.format({ async = false })
		end,
	})
end

local cmd_args = {
	"java",
	"-Declipse.application=org.eclipse.jdt.ls.core.id1",
	"-Dosgi.bundles.defaultStartLevel=4",
	"-Declipse.product=org.eclipse.jdt.ls.core.product",
	"-Dlog.protocol=true",
	"-Dlog.level=ALL",
	"-Xmx1G",
	"--add-modules=ALL-SYSTEM",
	"--add-opens",
	"java.base/java.util=ALL-UNNAMED",
	"--add-opens",
	"java.base/java.lang=ALL-UNNAMED",
}

if lombok_jar ~= "" and vim.fn.filereadable(lombok_jar) == 1 then
	table.insert(cmd_args, "-javaagent:" .. lombok_jar)
end

table.insert(cmd_args, "-Dosgi.sharedConfiguration.area=" .. nix_config_dir)
table.insert(cmd_args, "-Dosgi.sharedConfiguration.area.readOnly=true")
table.insert(cmd_args, "-Dosgi.configuration.cascaded=true")
table.insert(cmd_args, "-jar")
table.insert(cmd_args, launcher_jar)
table.insert(cmd_args, "-configuration")
table.insert(cmd_args, user_config_dir)
table.insert(cmd_args, "-data")
table.insert(cmd_args, workspace_dir)

-- 3. Configuración base del inicio de JDTLS
local config = {
	cmd = cmd_args,

	init_options = {
		bundles = bundles,
	},

	on_attach = on_attach,

	-- Marcamos la raíz del proyecto buscando archivos de Maven o Gradle
	root_dir = require("jdtls.setup").find_root({ ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
	settings = {
		java = {
			profile = {
				updateOnSave = true,
			},
			compiler = {
				annotationProcessing = {
					enabled = true,
				},
			},
			codeGeneration = {
				hashCodeEquals = {
					useJava7Objects = true, -- Objects.hash(...) / Objects.equals(...)
					useInstanceof = true, -- 'instanceof' en vez de getClass()
				},
				toString = {
					template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
					codeStyle = "STRING_CONCATENATION", -- o STRING_BUILDER, STRING_BUILDER_CHAINED, STRING_FORMAT
					skipNullValues = false,
					listArrayContents = true,
					limitElements = 0,
				},
				generateComments = false, -- ya tienes tus propios snippets de Javadoc, no hace falta que jdtls meta los suyos
				useBlocks = true,
				insertionLocation = "afterCursor",
			},
			-- [FIX 3] Runtime de Java explícito para que JDTLS pueda resolver
			-- el ejecutable "java" al lanzar tests/debug (necesario con Nix,
			-- donde no hay una ruta estándar tipo /usr/lib/jvm/...).
			configuration = {
				runtimes = java_home ~= "" and {
					{
						name = "JavaSE-21",
						path = java_home,
						default = true,
					},
				} or nil,
			},
		},
	},
}

-- Arrancamos o nos adjuntamos al servidor de Java
require("jdtls").start_or_attach(config)
