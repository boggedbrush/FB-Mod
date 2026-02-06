package net.filebot.web;

import static java.util.Arrays.*;

import javax.swing.Icon;

public interface Datasource {

	String getIdentifier();

	Icon getIcon();

	default String getName() {
		return getIdentifier();
	}

	default boolean supportsSearch() {
		return this instanceof MovieIdentificationService || this instanceof EpisodeListProvider;
	}

	default boolean supportsEpisodeLookup() {
		return this instanceof EpisodeListProvider;
	}

	default boolean supportsMovieLookup() {
		return this instanceof MovieIdentificationService;
	}

	default boolean requiresAuthentication() {
		return false;
	}

	default boolean isEnabled() {
		String disabled = System.getProperty("net.filebot.provider.disabled", "");
		if (disabled.trim().isEmpty()) {
			return true;
		}

		String identifier = getIdentifier();
		return stream(disabled.split("\\s*,\\s*")).filter(s -> !s.isEmpty()).noneMatch(it -> it.equalsIgnoreCase(identifier));
	}

	default String getStatusMessage() {
		return isEnabled() ? "enabled" : "disabled by net.filebot.provider.disabled";
	}

}
