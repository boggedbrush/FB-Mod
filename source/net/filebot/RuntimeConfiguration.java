package net.filebot;

import static net.filebot.Logging.*;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;

import net.filebot.cli.ArgumentBean;

public final class RuntimeConfiguration {

	private static final AtomicBoolean warnedBundledApiFallback = new AtomicBoolean(false);
	private static final Set<String> warnedLegacyProperties = ConcurrentHashMap.newKeySet();
	private static volatile boolean initialized = false;

	private RuntimeConfiguration() {
		throw new UnsupportedOperationException();
	}

	public static synchronized void configure(ArgumentBean args) {
		if (initialized) {
			return;
		}

		Properties properties = new Properties();
		File configFile = resolveConfigFile(args);
		if (configFile == null) {
			configFile = createDefaultConfigTemplateIfMissing();
		}

		if (configFile != null) {
			loadProperties(properties, configFile);
		}

		applyProperties(properties);
		applyEnvironmentOverrides();
		applyCommandLineOverrides(args);
		applyDerivedOverrides();

		initialized = true;
	}

	private static File resolveConfigFile(ArgumentBean args) {
		String fromArgs = args == null ? null : args.getConfigPath();
		String fromEnv = System.getenv("FB_MOD_CONFIG");
		String path = firstNonBlank(fromArgs, fromEnv);

		if (path != null) {
			return new File(path).getAbsoluteFile();
		}

		Path home = Paths.get(System.getProperty("user.home", "."));
		File modern = home.resolve(".config/fb-mod/config.properties").toFile();
		if (modern.isFile()) {
			return modern;
		}

		File legacy = home.resolve(".fb-mod/config.properties").toFile();
		if (legacy.isFile()) {
			return legacy;
		}

		return null;
	}

	private static File createDefaultConfigTemplateIfMissing() {
		Path configPath = Paths.get(System.getProperty("user.home", ".")).resolve(".config/fb-mod/config.properties");
		if (Files.exists(configPath)) {
			return configPath.toFile();
		}

		try {
			Files.createDirectories(configPath.getParent());
			try (BufferedWriter writer = Files.newBufferedWriter(configPath, StandardCharsets.UTF_8)) {
				writer.write("# FB-Mod runtime configuration");
				writer.newLine();
				writer.write("# Generated automatically on first launch.");
				writer.newLine();
				writer.newLine();
				writer.write("# Provider order (comma-separated)");
				writer.newLine();
				writer.write("net.filebot.provider.order=TheMovieDB::TV,TVmaze,TheTVDB,AniDB");
				writer.newLine();
				writer.newLine();
				writer.write("# Optional data mirror path / URL");
				writer.newLine();
				writer.write("# url.data.source=/path/to/fb-mod-mirror");
				writer.newLine();
				writer.newLine();
				writer.write("# Optional provider disable list");
				writer.newLine();
				writer.write("# net.filebot.provider.disabled=TheTVDB,AniDB");
				writer.newLine();
				writer.newLine();
				writer.write("# API keys (recommended)");
				writer.newLine();
				writer.write("# apikey.themoviedb=");
				writer.newLine();
				writer.write("# apikey.omdb=");
				writer.newLine();
			}

			log.info("Created default runtime config template: " + configPath);
			return configPath.toFile();
		} catch (Exception e) {
			log.log(Level.WARNING, "Failed to create default runtime config template: " + configPath, e);
			return null;
		}
	}

	private static void loadProperties(Properties properties, File configFile) {
		try (InputStream input = new FileInputStream(configFile)) {
			properties.load(input);
			System.setProperty("net.filebot.config.path", configFile.getAbsolutePath());
			log.info("Loaded runtime config: " + configFile);
		} catch (Exception e) {
			log.log(Level.WARNING, "Failed to load runtime config: " + configFile, e);
		}
	}

	private static void applyProperties(Properties properties) {
		for (String key : properties.stringPropertyNames()) {
			String value = properties.getProperty(key);
			if (value != null && !value.trim().isEmpty()) {
				System.setProperty(key.trim(), value.trim());
			}
		}
	}

	private static void applyEnvironmentOverrides() {
		Map<String, String> map = new LinkedHashMap<>();
		map.put("FB_MOD_DATA_SOURCE", "url.data.source");
		map.put("FB_MOD_PROVIDER_ORDER", "net.filebot.provider.order");
		map.put("FB_MOD_PROVIDER_DISABLED", "net.filebot.provider.disabled");
		map.put("FB_MOD_GITHUB_STABLE", "github.stable");
		map.put("FB_MOD_GITHUB_MASTER", "github.master");

		map.forEach((env, key) -> setIfPresent(key, System.getenv(env)));

		getApiKeyEnvMap().forEach((env, key) -> setIfPresent("apikey." + key, System.getenv(env)));
	}

	private static void applyCommandLineOverrides(ArgumentBean args) {
		if (args == null) {
			return;
		}

		setIfPresent("url.data.source", args.getDataSource());
		setIfPresent("net.filebot.provider.order", args.getProviderOrder());
	}

	private static void applyDerivedOverrides() {
		String base = System.getProperty("url.data.source");
		if (base == null || base.trim().isEmpty()) {
			return;
		}

		if (System.getProperty("github.stable") == null) {
			System.setProperty("github.stable", resolve(base, "scripts/fn.jar.xz"));
		}

		if (System.getProperty("github.master") == null) {
			System.setProperty("github.master", ensureTrailingSlash(resolve(base, "scripts/master")));
		}
	}

	public static String getApplicationProperty(String key, String fallback) {
		String value = System.getProperty(key);
		return (value == null || value.trim().isEmpty()) ? fallback : value.trim();
	}

	public static String getApiKey(String name, String fallback) {
		String key = "apikey." + name;
		String value = System.getProperty(key);
		if (value != null && !value.trim().isEmpty()) {
			return value.trim();
		}

		String env = getApiKeyEnvMap().entrySet().stream().filter(e -> e.getValue().equals(name)).map(Map.Entry::getKey).findFirst().orElse(null);
		if (env != null) {
			String envValue = System.getenv(env);
			if (envValue != null && !envValue.trim().isEmpty()) {
				return envValue.trim();
			}
		}

		if (fallback != null && !fallback.trim().isEmpty() && warnedBundledApiFallback.compareAndSet(false, true)) {
			log.info("Using bundled API key defaults; configure env or --config to override.");
		}

		return fallback;
	}

	public static void warnLegacyProperty(String key, String message) {
		if (warnedLegacyProperties.add(key)) {
			log.warning(message);
		}
	}

	private static void setIfPresent(String key, String value) {
		if (value != null && !value.trim().isEmpty()) {
			System.setProperty(key, value.trim());
		}
	}

	private static Map<String, String> getApiKeyEnvMap() {
		Map<String, String> map = new LinkedHashMap<>();
		map.put("FB_MOD_APIKEY_THEMOVIEDB", "themoviedb");
		map.put("FB_MOD_APIKEY_THETVDB", "thetvdb");
		map.put("FB_MOD_APIKEY_OMDB", "omdb");
		map.put("FB_MOD_APIKEY_FANART_TV", "fanart.tv");
		map.put("FB_MOD_APIKEY_ACOUSTID", "acoustid");
		map.put("FB_MOD_APIKEY_ANIDB", "anidb");
		map.put("FB_MOD_APIKEY_OPENSUBTITLES", "opensubtitles");
		map.put("FB_MOD_APIKEY_GOOGLE_GEOCODE", "google.geocode");
		return map;
	}

	private static String resolve(String base, String path) {
		try {
			String normalizedPath = path.startsWith("/") ? path.substring(1) : path;
			if (base.contains("://")) {
				return URI.create(ensureTrailingSlash(base)).resolve(normalizedPath).toString();
			}

			File root = new File(base);
			if (root.isDirectory()) {
				return root.toPath().resolve(normalizedPath).toUri().toString();
			}

			return root.toURI().resolve(normalizedPath).toString();
		} catch (Exception e) {
			log.log(Level.WARNING, "Failed to resolve runtime data source: " + base + " + " + path, e);
			return base;
		}
	}

	private static String ensureTrailingSlash(String value) {
		return value.endsWith("/") ? value : value + '/';
	}

	private static String firstNonBlank(String... values) {
		for (String value : values) {
			if (value != null && !value.trim().isEmpty()) {
				return value.trim();
			}
		}
		return null;
	}

	public static String describeSupportedEnvironmentVariables() {
		Set<String> names = new TreeSet<>();
		names.add("FB_MOD_CONFIG");
		names.add("FB_MOD_DATA_SOURCE");
		names.add("FB_MOD_PROVIDER_ORDER");
		names.add("FB_MOD_PROVIDER_DISABLED");
		names.add("FB_MOD_GITHUB_STABLE");
		names.add("FB_MOD_GITHUB_MASTER");
		names.addAll(getApiKeyEnvMap().keySet());
		return String.join(", ", names);
	}
}
