package net.filebot;

import static java.awt.GraphicsEnvironment.*;
import static java.util.Arrays.*;
import static java.util.stream.Collectors.*;
import static net.filebot.ExitCode.*;
import static net.filebot.Logging.*;
import static net.filebot.MediaTypes.*;
import static net.filebot.Settings.*;
import static net.filebot.ui.GettingStartedUtil.*;
import static net.filebot.util.FileUtilities.*;
import static net.filebot.util.FileUtilities.getChildren;
import static net.filebot.util.XPathUtilities.*;
import static net.filebot.util.ui.SwingUI.*;

import java.awt.Dialog.ModalityType;
import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.security.CodeSource;
import java.security.Permission;
import java.security.PermissionCollection;
import java.security.Permissions;
import java.security.Policy;
import java.security.ProtectionDomain;
import java.util.List;
import java.util.Map;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.prefs.Preferences;

import javax.swing.JDialog;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

import org.kohsuke.args4j.CmdLineException;
import org.w3c.dom.Document;

import net.filebot.cli.ArgumentBean;
import net.filebot.cli.ArgumentProcessor;
import net.filebot.format.ExpressionFormat;
import net.filebot.platform.mac.MacAppUtilities;
import net.filebot.platform.windows.WinAppUtilities;
import net.filebot.ui.FileBotMenuBar;
import net.filebot.ui.MainFrame;
import net.filebot.ui.NotificationHandler;
import net.filebot.ui.PanelBuilder;
import net.filebot.ui.SinglePanelFrame;
import net.filebot.ui.SupportDialog;
import net.filebot.ui.transfer.FileTransferable;
import net.filebot.util.PreferencesMap.PreferencesEntry;
import net.filebot.util.ui.SwingEventBus;
import net.miginfocom.swing.MigLayout;

public class Main {

	public static void main(String[] argv) {
		try {
			// Set macOS appearance BEFORE any AWT/Swing initialization
			// This must happen before any AWT classes are loaded
			if (System.getProperty("os.name", "").toLowerCase().contains("mac")) {
				try {
					// Check if dark mode is enabled
					Process p = Runtime.getRuntime()
							.exec(new String[] { "defaults", "read", "-g", "AppleInterfaceStyle" });
					boolean isDark = (p.waitFor() == 0);
					System.setProperty("apple.awt.application.appearance",
							isDark ? "NSAppearanceNameDarkAqua" : "NSAppearanceNameAqua");
				} catch (Exception e) {
					// Ignore - will use default appearance
				}
			}

			// parse arguments
			ArgumentBean args = ArgumentBean.parse(argv);
			RuntimeConfiguration.configure(args);
			logStartupDiagnostics(args);

			// just print help message or version string and then exit
			if (args.printHelp()) {
				log.info(String.format("%s%n%n%s", getApplicationIdentifier(), args.usage()));
				System.exit(SUCCESS);
			}

			if (args.printVersion()) {
				log.info(String.join(" / ", getApplicationIdentifier(), getJavaRuntimeIdentifier(),
						getSystemIdentifier()));
				System.exit(SUCCESS);
			}

			if (args.clearCache() || args.clearUserData()) {
				// clear persistent user preferences
				if (args.clearUserData()) {
					log.info("Reset preferences");
					Settings.forPackage(Main.class).clear();

					// restore preferences on start if empty (TODO: remove after a few releases)
					ApplicationFolder.AppData.resolve("preferences.backup.xml").delete();
				}

				// clear caches
				if (args.clearCache()) {
					// clear cache must be called manually
					if (System.console() == null) {
						log.severe("`filebot -clear-cache` must be called from an interactive console.");
						System.exit(ERROR);
					}

					log.info("Clear cache");
					for (File folder : getChildren(ApplicationFolder.Cache.get(), FOLDERS)) {
						log.fine("* Delete " + folder);
						delete(folder);
					}
				}

				// just clear cache and/or settings and then exit
				System.exit(SUCCESS);
			}

			// make sure we can access application arguments at any time
			setApplicationArguments(args);

			// update system properties
			log.info("Initialize system properties");
			initializeSystemProperties(args);
			log.info("Initialize logging");
			initializeLogging(args);

			// initialize this stuff before anything else
			log.info("Initialize cache manager");
			CacheManager.getInstance();
			log.info("Initialize security manager");
			initializeSecurityManager();

			// initialize history spooler
			HistorySpooler.getInstance().setPersistentHistoryEnabled(useRenameHistory());

			// CLI mode => run command-line interface and then exit
			if (args.runCLI()) {
				// just import and print license when running with --license option
				/*
				 * if (LICENSE.isFile()) {
				 * String psm = args.getLicenseKey();
				 * if (psm != null) {
				 * configureLicense(psm);
				 * System.exit(SUCCESS);
				 * }
				 * }
				 */

				int status = new ArgumentProcessor().run(args);
				System.exit(status);
			}

			// just print help page if we can't run any command and also can't start the GUI
			if (isHeadless()) {
				log.info(String.format("%s / %s (headless)%n%n%s", getApplicationIdentifier(),
						getJavaRuntimeIdentifier(), args.usage()));
				System.exit(ERROR);
			}

			// GUI mode => start user interface
			SwingUtilities.invokeLater(() -> {
				// restore preferences on start if empty (TODO: remove after a few releases)
				try {
					if (Preferences.userNodeForPackage(Main.class).keys().length == 0) {
						File f = ApplicationFolder.AppData.resolve("preferences.backup.xml");
						if (f.exists()) {
							log.fine("Restore user preferences: " + f);
							Settings.restore(f);
						} else {
							log.fine("No user preferences found: " + f);
						}
					}
				} catch (Exception e) {
					debug.log(Level.WARNING, "Failed to restore preferences", e);
				}

				try {
					startUserInterface(args);

					// run background tasks
					newSwingWorker(() -> onStart(args)).execute();
				} catch (Throwable e) {
					debug.log(Level.SEVERE, "Failed to initialize user interface", e);
				}
			});
		} catch (CmdLineException e) {
			// illegal arguments => print CLI error message
			log.severe(e::getMessage);
			System.exit(ERROR);
		} catch (Throwable e) {
			// unexpected error => dump stack
			debug.log(Level.SEVERE, "Error during startup", e);
			System.exit(ERROR);
		}
	}

	private static void onStart(ArgumentBean args) throws Exception {
		log.info("Startup background tasks begin");

		// publish file arguments
		List<File> files = args.getFiles(false);
		if (files.size() > 0) {
			log.info("Publishing startup file arguments: " + files.size());
			SwingEventBus.getInstance().post(new FileTransferable(files));
		}

		// import license if launched with license file
		/*
		 * if (LICENSE.isFile()) {
		 * try {
		 * String psm = args.getLicenseKey();
		 * if (psm != null) {
		 * configureLicense(psm);
		 * }
		 * } catch (Throwable e) {
		 * debug.log(Level.WARNING, e, e::getMessage);
		 * }
		 * }
		 */

		// JavaFX is used for ProgressMonitor and GettingStartedDialog
		try {
			log.info("Initialize JavaFX toolkit");
			initJavaFX();
		} catch (Throwable e) {
			log.log(Level.SEVERE, "Failed to initialize JavaFX", e);
		}

		// check if application help should be shown
		if (!"skip".equals(System.getProperty("application.help"))) {
			try {
				checkGettingStarted();
			} catch (Throwable e) {
				debug.log(Level.WARNING, "Failed to show Getting Started help", e);
			}
		}

		log.info("Startup background tasks done");

		// check for application updates
		/*
		 * if (!"skip".equals(System.getProperty("application.update"))) {
		 * try {
		 * checkUpdate();
		 * } catch (Throwable e) {
		 * debug.log(Level.WARNING, "Failed to check for updates", e);
		 * }
		 * }
		 */
	}

	private static void startUserInterface(ArgumentBean args) {
		// initialize FlatLaf
		String theme = Settings.forPackage(Main.class).get("ui.theme", "System");
		try {
			if ("Dark".equalsIgnoreCase(theme)) {
				com.formdev.flatlaf.FlatDarkLaf.setup();
				// Enable dark title bar on macOS
				if (com.formdev.flatlaf.util.SystemInfo.isMacOS) {
					System.setProperty("apple.awt.application.appearance", "NSAppearanceNameDarkAqua");
				}
			} else if ("Light".equalsIgnoreCase(theme)) {
				com.formdev.flatlaf.FlatLightLaf.setup();
				// Ensure light title bar on macOS
				if (com.formdev.flatlaf.util.SystemInfo.isMacOS) {
					System.setProperty("apple.awt.application.appearance", "NSAppearanceNameAqua");
				}
			} else {
				// System preference (default)
				if (com.formdev.flatlaf.util.SystemInfo.isMacOS) {
					// Auto-detect dark mode using system command since simple API might check older
					// AWT settings
					boolean isDark = false;
					try {
						// "defaults read -g AppleInterfaceStyle" returns "Dark" (exit code 0) if dark
						// mode is on
						Process p = Runtime.getRuntime()
								.exec(new String[] { "defaults", "read", "-g", "AppleInterfaceStyle" });
						isDark = (p.waitFor() == 0);
					} catch (Exception e) {
						// ignore
					}

					if (isDark) {
						log.config("Detected macOS Dark Mode");
						com.formdev.flatlaf.themes.FlatMacDarkLaf.setup();
					} else {
						com.formdev.flatlaf.themes.FlatMacLightLaf.setup();
					}

					if (com.formdev.flatlaf.util.SystemInfo.isMacFullWindowContentSupported) {
						// enables dark title bar for all windows
						System.setProperty("apple.awt.application.appearance",
								isDark ? "NSAppearanceNameDarkAqua" : "NSAppearanceNameAqua");
					}
				} else {
					com.formdev.flatlaf.FlatLaf.setup(new com.formdev.flatlaf.themes.FlatMacLightLaf());
				}

				// Check user preference overrides
				if ("Dark".equalsIgnoreCase(theme)) {
					com.formdev.flatlaf.FlatDarkLaf.setup();
				} else if ("Light".equalsIgnoreCase(theme)) {
					com.formdev.flatlaf.FlatLightLaf.setup();
				}

				log.info("Using FlatLaf: " + javax.swing.UIManager.getLookAndFeel().getName());
			}
		} catch (Exception e) {
			log.log(Level.WARNING, "Failed to initialize FlatLaf", e);
			setSystemLookAndFeel();
		}

		// start standard frame or single panel frame
		PanelBuilder[] panels = args.getPanelBuilders();
		log.info("Initialize UI panels: " + stream(panels).map(PanelBuilder::getName).collect(joining(", ")));

		// MAS does not allow subtitle applications
		if (isMacSandbox()) {
			panels = stream(panels).filter(p -> !p.getName().equals("Subtitles")).toArray(PanelBuilder[]::new);
		}

		JFrame frame = panels.length > 1 ? new MainFrame(panels) : new SinglePanelFrame(panels[0]);

		// Apply macOS dark title bar if using dark theme
		if (com.formdev.flatlaf.util.SystemInfo.isMacOS) {
			boolean isDarkTheme = javax.swing.UIManager.getLookAndFeel().getName().toLowerCase().contains("dark");
			frame.getRootPane().putClientProperty("apple.awt.windowDarkAppearance", isDarkTheme);
		}

		try {
			restoreWindowBounds(frame, Settings.forPackage(MainFrame.class)); // restore previous size and location
		} catch (Exception e) {
			frame.setLocation(120, 80); // make sure the main window is not displayed out of screen bounds
		}

		frame.addWindowListener(windowClosed(evt -> {
			evt.getWindow().setVisible(false);

			// make sure any long running operations are done now and not later on the
			// shutdown hook thread
			HistorySpooler.getInstance().commit();

			if (isAppStore()) {
				SupportDialog.AppStoreReview.maybeShow();
			}

			// restore preferences on start if empty (TODO: remove after a few releases)
			Settings.store(ApplicationFolder.AppData.resolve("preferences.backup.xml"));

			System.exit(0);
		}));

		// configure main window
		if (isMacApp()) {
			// macOS-specific configuration
			MacAppUtilities.initializeApplication(FileBotMenuBar.createHelp(), files -> {
				if (LICENSE.isFile() && files.size() == 1 && containsOnly(files, LICENSE_FILES)) {
					configureLicense(files.get(0));
				} else {
					SwingEventBus.getInstance().post(new FileTransferable(files));
				}
			});
		} else if (isWindowsApp()) {
			// Windows-specific configuration
			WinAppUtilities.initializeApplication(isUWP() ? null : getApplicationName());
			frame.setIconImages(ResourceManager.getApplicationIconImages());
		} else {
			// generic Linux / FreeBSD / Solaris configuration
			frame.setIconImages(ResourceManager.getApplicationIconImages());
		}

		// start application
		frame.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
		frame.setVisible(true);
		log.info("Main window is visible");
	}

	/**
	 * Show update notifications if updates are available
	 */
	/*
	 * private static void checkUpdate() throws Exception {
	 * Cache cache = Cache.getCache(getApplicationName(), CacheType.Persistent);
	 * Document dom = cache.xml(getApplicationProperty("update.url"),
	 * URL::new).expire(Cache.ONE_WEEK).retry(0).get();
	 * 
	 * // flush to disk
	 * cache.flush();
	 * 
	 * // parse update xml
	 * Map<String, String> update =
	 * streamElements(dom.getFirstChild()).collect(toMap(n -> n.getNodeName(), n ->
	 * n.getTextContent().trim()));
	 * 
	 * // check if update is required
	 * int latestRev = Integer.parseInt(update.get("revision"));
	 * int currentRev = getApplicationRevisionNumber();
	 * 
	 * if (latestRev > currentRev && currentRev > 0) {
	 * SwingUtilities.invokeLater(() -> {
	 * JDialog dialog = new JDialog(JFrame.getFrames()[0], update.get("title"),
	 * ModalityType.APPLICATION_MODAL);
	 * JPanel pane = new JPanel(new MigLayout("fill, nogrid, insets dialog"));
	 * dialog.setContentPane(pane);
	 * 
	 * pane.add(new JLabel(ResourceManager.getIcon("window.icon.medium")),
	 * "aligny top");
	 * pane.add(new JLabel(update.get("message")),
	 * "aligny top, gap 10, wrap paragraph:push");
	 * 
	 * pane.add(newButton("Download", ResourceManager.getIcon("dialog.continue"),
	 * evt -> {
	 * openURI(update.get("download"));
	 * dialog.setVisible(false);
	 * }), "tag ok");
	 * 
	 * pane.add(newButton("Details", ResourceManager.getIcon("action.report"), evt
	 * -> {
	 * openURI(update.get("discussion"));
	 * }), "tag help2");
	 * 
	 * pane.add(newButton("Ignore", ResourceManager.getIcon("dialog.cancel"), evt ->
	 * {
	 * dialog.setVisible(false);
	 * }), "tag cancel");
	 * 
	 * dialog.pack();
	 * dialog.setLocation(getOffsetLocation(dialog.getOwner()));
	 * dialog.setVisible(true);
	 * });
	 * }
	 * }
	 */

	/**
	 * Show Getting Started to new users
	 */
	private static void checkGettingStarted() throws Exception {
		PreferencesEntry<String> started = Settings.forPackage(Main.class).entry("getting.started").defaultValue("0");
		if ("0".equals(started.getValue())) {
			started.setValue("1");
			started.flush();

			// open Getting Started
			SwingUtilities.invokeLater(() -> openGettingStarted("show".equals(System.getProperty("application.help"))));
		}
	}

	private static void restoreWindowBounds(JFrame window, Settings settings) {
		// store bounds on close
		window.addWindowListener(windowClosed(evt -> {
			// don't save window bounds if window is maximized
			if (!isMaximized(window)) {
				settings.put("window.x", String.valueOf(window.getX()));
				settings.put("window.y", String.valueOf(window.getY()));
				settings.put("window.width", String.valueOf(window.getWidth()));
				settings.put("window.height", String.valueOf(window.getHeight()));
			}
		}));

		// restore bounds
		int x = Integer.parseInt(settings.get("window.x"));
		int y = Integer.parseInt(settings.get("window.y"));
		int width = Integer.parseInt(settings.get("window.width"));
		int height = Integer.parseInt(settings.get("window.height"));
		window.setBounds(x, y, width, height);
	}

	/**
	 * Initialize default SecurityManager and grant all permissions via security
	 * policy. Initialization is required in order to run {@link ExpressionFormat}
	 * in a secure sandbox.
	 */
	private static void initializeSecurityManager() {
		// java.lang.SecurityManager is deprecated for removal and emits unavoidable
		// runtime warnings on modern JDKs
		if (Runtime.version().feature() >= 17) {
			debug.fine("Skipping legacy security manager initialization on Java " + Runtime.version().feature());
			return;
		}

		try {
			// initialize security policy used by the default security manager
			// because default the security policy is very restrictive (e.g. no
			// FilePermission)
			Policy.setPolicy(new Policy() {

				@Override
				public boolean implies(ProtectionDomain domain, Permission permission) {
					// all permissions
					return true;
				}

				@Override
				public PermissionCollection getPermissions(CodeSource codesource) {
					// VisualVM can't connect if this method does return
					// a checked immutable PermissionCollection
					return new Permissions();
				}
			});

			// set default security manager
			System.setSecurityManager(new SecurityManager());
		} catch (Throwable e) {
			// security manager was probably set via system property
			debug.log(Level.WARNING,
					"Security manager unavailable; expression sandbox will run without legacy security manager", e);
		}
	}

	private static void logStartupDiagnostics(ArgumentBean args) {
		log.info(String.format("Starting %s", getApplicationIdentifier()));
		log.info(String.format("Runtime: %s / %s", getJavaRuntimeIdentifier(), getSystemIdentifier()));
		log.info("Arguments: " + args);

		String configPath = System.getProperty("net.filebot.config.path");
		if (configPath != null && !configPath.isEmpty()) {
			log.info("Runtime config: " + configPath);
		}

		String dataSource = System.getProperty("url.data.source");
		if (dataSource != null && !dataSource.isEmpty()) {
			log.info("Data source override: " + dataSource);
		}
	}

	public static void initializeSystemProperties(ArgumentBean args) {
		System.setProperty("http.agent", String.format("%s/%s", getApplicationName(), getApplicationVersion()));
		System.setProperty("sun.net.client.defaultConnectTimeout", "10000");
		System.setProperty("sun.net.client.defaultReadTimeout", "60000");

		System.setProperty("swing.crossplatformlaf", "javax.swing.plaf.nimbus.NimbusLookAndFeel");
		System.setProperty("grape.root", ApplicationFolder.AppData.resolve("grape").getPath());
		System.setProperty("org.apache.commons.logging.Log", "org.apache.commons.logging.impl.NoOpLog");

		if (args.unixfs) {
			System.setProperty("unixfs", "true");
		}

		if (args.disableExtendedAttributes) {
			System.setProperty("useExtendedFileAttributes", "false");
			System.setProperty("useCreationDate", "false");
		}
	}

	public static void initializeLogging(ArgumentBean args) throws IOException {
		// make sure that these folders exist
		ApplicationFolder.TemporaryFiles.get().mkdirs();
		ApplicationFolder.AppData.get().mkdirs();

		if (args.runCLI()) {
			// CLI logging settings
			log.setLevel(args.getLogLevel());
		} else {
			// GUI logging settings
			log.setLevel(Level.INFO);
			log.addHandler(new NotificationHandler(getApplicationName()));

			// log errors to file
			try {
				Handler errorLogHandler = createSimpleFileHandler(ApplicationFolder.AppData.resolve("error.log"),
						Level.WARNING);
				log.addHandler(errorLogHandler);
				debug.addHandler(errorLogHandler);
			} catch (Exception e) {
				log.log(Level.WARNING, "Failed to initialize error log", e);
			}
		}

		// tee stdout and stderr to log file if --log-file is set
		if (args.logFile != null) {
			Handler logFileHandler = createLogFileHandler(args.getLogFile(), args.logLock, Level.ALL);
			log.addHandler(logFileHandler);
			debug.addHandler(logFileHandler);
		}
	}

}
