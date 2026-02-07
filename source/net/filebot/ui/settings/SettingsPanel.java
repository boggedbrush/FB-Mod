package net.filebot.ui.settings;

import static net.filebot.Settings.*;
import static net.filebot.util.ui.SwingUI.*;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.event.ActionEvent;

import javax.swing.BorderFactory;
import javax.swing.ButtonGroup;
import javax.swing.JButton;
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JRadioButton;
import javax.swing.SwingConstants;

import net.filebot.CacheManager;
import net.filebot.ResourceManager;
import net.filebot.Settings;
import net.miginfocom.swing.MigLayout;

public class SettingsPanel extends JComponent {

    private JRadioButton lightTheme;
    private JRadioButton darkTheme;
    private JRadioButton systemTheme;

    public SettingsPanel() {
        setLayout(new BorderLayout());

        JPanel contentPanel = new JPanel(new MigLayout("insets dialog, wrap 1", "[grow, fill]", ""));

        // Header
        JLabel header = new JLabel("Settings");
        header.setFont(header.getFont().deriveFont(20f));
        header.setHorizontalAlignment(SwingConstants.CENTER);
        contentPanel.add(header, "gapbottom 20");

        // Theme Section
        contentPanel.add(createThemeSection(), "growx");

        // Cache Section
        contentPanel.add(createCacheSection(), "growx, gaptop 20");

        // About Section
        contentPanel.add(createAboutSection(), "growx, gaptop 20");

        add(contentPanel, BorderLayout.NORTH);
    }

    private JPanel createThemeSection() {
        JPanel panel = new JPanel(new MigLayout("insets 10, wrap 1", "[grow]", ""));
        panel.setBorder(BorderFactory.createTitledBorder("Appearance"));

        JLabel themeLabel = new JLabel("Theme");
        themeLabel.setFont(themeLabel.getFont().deriveFont(14f));
        panel.add(themeLabel, "gapbottom 5");

        // Get current theme
        String currentTheme = Settings.forPackage(net.filebot.Main.class).get("ui.theme", "System");

        lightTheme = new JRadioButton("Light");
        darkTheme = new JRadioButton("Dark");
        systemTheme = new JRadioButton("System");

        ButtonGroup themeGroup = new ButtonGroup();
        themeGroup.add(lightTheme);
        themeGroup.add(darkTheme);
        themeGroup.add(systemTheme);

        // Set current selection
        switch (currentTheme) {
            case "Light":
                lightTheme.setSelected(true);
                break;
            case "Dark":
                darkTheme.setSelected(true);
                break;
            default:
                systemTheme.setSelected(true);
                break;
        }

        // Add action listeners
        lightTheme.addActionListener(e -> setTheme("Light"));
        darkTheme.addActionListener(e -> setTheme("Dark"));
        systemTheme.addActionListener(e -> setTheme("System"));

        JPanel radioPanel = new JPanel(new MigLayout("insets 0", "[]15[]15[]", ""));
        radioPanel.add(lightTheme);
        radioPanel.add(darkTheme);
        radioPanel.add(systemTheme);
        panel.add(radioPanel);

        return panel;
    }

    private JPanel createCacheSection() {
        JPanel panel = new JPanel(new MigLayout("insets 10", "[grow][shrink]", ""));
        panel.setBorder(BorderFactory.createTitledBorder("Data"));

        JLabel cacheLabel = new JLabel("Clear cached data and metadata");
        panel.add(cacheLabel, "growx");

        JButton clearCacheButton = new JButton("Clear Cache");
        clearCacheButton.setIcon(ResourceManager.getIcon("action.clear"));
        clearCacheButton.addActionListener(this::clearCache);
        panel.add(clearCacheButton);

        return panel;
    }

    private JPanel createAboutSection() {
        JPanel panel = new JPanel(new MigLayout("insets 10, wrap 1", "[grow]", ""));
        panel.setBorder(BorderFactory.createTitledBorder("About"));

        panel.add(new JLabel("Application: " + getApplicationName()));
        panel.add(new JLabel("Version: " + getApplicationVersion()));

        return panel;
    }

    private void setTheme(String theme) {
        Settings.forPackage(net.filebot.Main.class).put("ui.theme", theme);
        JOptionPane.showMessageDialog(this,
                "Please restart the application to apply the theme change.",
                "Theme Changed",
                JOptionPane.INFORMATION_MESSAGE);
    }

    private void clearCache(ActionEvent e) {
        try {
            CacheManager.getInstance().clearAll();
            JOptionPane.showMessageDialog(this,
                    "Cache cleared successfully.",
                    "Cache Cleared",
                    JOptionPane.INFORMATION_MESSAGE);
        } catch (Exception ex) {
            JOptionPane.showMessageDialog(this,
                    "Failed to clear cache: " + ex.getMessage(),
                    "Error",
                    JOptionPane.ERROR_MESSAGE);
        }
    }

}
