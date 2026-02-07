
package net.filebot.ui.settings;

import javax.swing.Icon;
import javax.swing.JComponent;

import net.filebot.ResourceManager;
import net.filebot.ui.PanelBuilder;

public class SettingsPanelBuilder implements PanelBuilder {

    @Override
    public String getName() {
        return "Settings";
    }

    @Override
    public Icon getIcon() {
        return ResourceManager.getIcon("panel.settings");
    }

    @Override
    public boolean equals(Object obj) {
        return obj instanceof SettingsPanelBuilder;
    }

    @Override
    public JComponent create() {
        return new SettingsPanel();
    }

}
