package net.filebot.ui;

import static javax.swing.BorderFactory.*;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.LinearGradientPaint;

import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingConstants;

import net.filebot.util.ui.GradientStyle;
import net.filebot.util.ui.notification.SeparatorBorder;
import net.filebot.util.ui.notification.SeparatorBorder.Position;

public class HeaderPanel extends JComponent {

	private JLabel titleLabel = new JLabel();

	private float[] gradientFractions = { 0.0f, 0.5f, 1.0f };
	private Color[] gradientColors = { new Color(0xF6F6F6), new Color(0xF8F8F8), new Color(0xF3F3F3) };

	public HeaderPanel() {
		setLayout(new BorderLayout());

		JPanel centerPanel = new JPanel(new BorderLayout());
		centerPanel.setOpaque(false);

		titleLabel.setHorizontalAlignment(SwingConstants.CENTER);
		titleLabel.setVerticalAlignment(SwingConstants.CENTER);
		titleLabel.setFont(new Font(Font.SANS_SERIF, Font.PLAIN, 24));

		centerPanel.setBorder(createEmptyBorder());
		centerPanel.add(titleLabel, BorderLayout.CENTER);

		add(centerPanel, BorderLayout.CENTER);

		setBorder(new javax.swing.border.MatteBorder(0, 0, 1, 0,
				javax.swing.UIManager.getColor("Component.borderColor")));
	}

	public void setTitle(String title) {
		titleLabel.setText(title);
	}

	public JLabel getTitleLabel() {
		return titleLabel;
	}

}
