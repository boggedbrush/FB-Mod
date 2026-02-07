package net.filebot.ui;

import static net.filebot.Settings.*;
import static net.filebot.util.ui.SwingUI.*;

import net.filebot.Settings;
import javax.swing.Action;
import javax.swing.JMenu;
import javax.swing.JMenuBar;

public class FileBotMenuBar {

	public static JMenuBar createHelp() {
		JMenuBar menuBar = new JMenuBar();

		JMenu theme = new JMenu("Theme");
		theme.add(newAction("Light", evt -> setTheme("Light")));
		theme.add(newAction("Dark", evt -> setTheme("Dark")));
		theme.add(newAction("System", evt -> setTheme("System")));
		menuBar.add(theme);

		JMenu help = new JMenu("Help");

		help.add(createLink("Getting Started", getApplicationProperty("link.intro")));
		help.add(createLink("FAQ", getApplicationProperty("link.faq")));
		help.add(createLink("Forums", getApplicationProperty("link.forums")));
		help.add(createLink("Discord Channel", getApplicationProperty("link.channel")));

		help.addSeparator();

		if (isMacSandbox()) {
			help.add(createLink("Report Bugs", getApplicationProperty("link.help.mas")));
			help.add(createLink("Request Help", getApplicationProperty("link.help.mas")));
		} else {
			help.add(createLink("Report Bugs", getApplicationProperty("link.bugs")));
			help.add(createLink("Request Help", getApplicationProperty("link.help")));
		}

		menuBar.add(help);

		return menuBar;
	}

	private static void setTheme(String theme) {
		Settings.forPackage(net.filebot.Main.class).put("ui.theme", theme);
		javax.swing.JOptionPane.showMessageDialog(null, "Please restart the application to apply the theme change.");
	}

	private static Action createLink(final String title, final String uri) {
		return newAction(title, null, evt -> openURI(uri));
	}

}
