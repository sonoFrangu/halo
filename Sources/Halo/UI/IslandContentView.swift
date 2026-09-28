import SwiftUI

/// Everything drawn inside the island body, laid out on the canvas at fixed frames from
/// `IslandLayout`. Artwork and equalizer persist across states and only change frame;
/// the player, header and alerts reveal their own elements in sequence.
struct IslandContentView: View {
    let island: IslandViewModel
    let models: IslandModels
    let actions: IslandActions
    let layout: IslandLayout

    var body: some View {
        let player = models.player
        let state = island.state
        let hasMedia = island.hasMedia
        let isExpanded = state == .expanded
        let showsPlayer = isExpanded && hasMedia && island.context.tab == .player
        let tint = player.palette.primary.color
        let timer = models.timers.timer

        ZStack(alignment: .topLeading) {
            ExpandedBackdrop(palette: player.palette, layout: layout, isVisible: showsPlayer)

            ArtworkView(
                image: player.artworkImage,
                palette: player.palette,
                cornerRadius: isExpanded ? 14 : 6,
                isProminent: isExpanded
            )
            .onTapGesture { actions.player.openSource() }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Apri l'app in riproduzione")
            .place(in: layout.artworkFrame(for: state))
            .opacity(hasMedia && (state == .compact || showsPlayer) ? 1 : 0)

            EqualizerView(isPlaying: player.isPlaying && hasMedia && state == .compact && timer == nil, tint: tint)
                .place(in: layout.equalizerFrame(for: state))
                .opacity(hasMedia && state == .compact && timer == nil ? 1 : 0)

            if let device = models.privacy.active {
                let alone = !hasMedia && timer == nil
                if alone {
                    PrivacyGlyph(kind: device)
                        .place(in: layout.artworkFrame(for: .compact))
                        .opacity(state == .compact ? 1 : 0)
                }
                PrivacyDot(kind: device)
                    .place(in: layout.privacyDotFrame(alone: alone))
                    .opacity(state == .compact ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: state)
            }

            if let timer {
                CompactTimerRing(timer: timer)
                    .place(in: layout.artworkFrame(for: .compact))
                    .opacity(state == .compact && !hasMedia ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: state)
                CompactTimerCountdown(timer: timer)
                    .place(in: layout.compactRightWingFrame)
                    .opacity(state == .compact ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: state)
            }

            PlayerContentView(island: island, models: models, actions: actions.player, layout: layout, isVisible: showsPlayer)

            EmptyStateView(availability: player.availability)
                .place(in: layout.emptyStateFrame)
                .reveal(isExpanded && !hasMedia && island.context.tab == .player, order: 0)

            ShelfView(
                store: models.shelf,
                thumbnails: models.thumbnails,
                isDropTargeted: island.isDropTargeted,
                actions: actions.shelf
            )
            .place(in: layout.tabBodyFrame)
            .reveal(isExpanded && island.context.tab == .shelf, order: 0)

            CalendarTabView(model: models.calendar, actions: actions.calendar)
                .place(in: layout.tabBodyFrame)
                .reveal(isExpanded && island.context.tab == .calendar, order: 0)

            TimerTabView(timers: models.timers, actions: actions.timer)
                .place(in: layout.tabBodyFrame)
                .reveal(isExpanded && island.context.tab == .timer, order: 0)
                .animation(.spring(duration: 0.4, bounce: 0.15), value: timer == nil)

            HeaderContentView(island: island, models: models, tint: tint, actions: actions, layout: layout)

            AlertContentView(
                island: island,
                models: models,
                tint: hasMedia ? tint : .white,
                actions: actions,
                layout: layout
            )
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }
}

/// The expanded player below the notch, with the lyrics panel when it is open.
struct PlayerContentView: View {
    let island: IslandViewModel
    let models: IslandModels
    let actions: PlayerActions
    let layout: IslandLayout
    let isVisible: Bool

    var body: some View {
        let player = models.player
        let lyrics = models.lyrics
        let tint = player.palette.primary.color
        let hasLyrics = lyrics.status == .synced

        ZStack(alignment: .topLeading) {
            SourceIconView(icon: player.sourceIcon)
                .place(in: layout.sourceIconFrame)
                .reveal(isVisible, order: 1)

            TrackInfoView(title: player.title, artist: player.artist)
                .place(in: layout.trackInfoFrame)
                .reveal(isVisible, order: 1)

            TransportControls(
                isPlaying: player.isPlaying,
                tint: tint,
                hasLyrics: hasLyrics,
                showsLyrics: lyrics.isPanelEnabled,
                actions: actions
            )
            .place(in: layout.controlsFrame)
            .reveal(isVisible, order: 2, blurs: false)

            ScrubberView(
                timeline: player.timeline,
                isActive: isVisible,
                tint: tint,
                isHovering: island.isScrubberHovered,
                onHoverChanged: { hovering in island.setScrubberHovered(hovering) },
                onScrubbingChanged: actions.setInteracting,
                onSeek: actions.seek
            )
            .place(in: layout.scrubberFrame)
            .reveal(isVisible, order: 3)

            LyricsPanel(
                lines: lyrics.lines,
                timeline: player.timeline,
                palette: player.palette,
                isVisible: isVisible && island.context.showsLyrics,
                onSeek: actions.seek
            )
            .place(in: layout.lyricsFrame)
            .reveal(isVisible && island.context.showsLyrics, order: 4)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }
}

/// The notch row of the expanded island: tabs in the left wing; in the right wing the
/// weather, or the next meeting when one is close, replaced by the HUD inline while it is
/// active (so a key press does not collapse an open island).
struct HeaderContentView: View {
    let island: IslandViewModel
    let models: IslandModels
    let tint: Color
    let actions: IslandActions
    let layout: IslandLayout

    var body: some View {
        let isExpanded = island.state == .expanded
        let showsInlineHUD = isExpanded && island.alert == .hud
        let headline = models.calendar.headline

        ZStack(alignment: .topLeading) {
            ExpandedTabsView(
                tabs: island.availableTabs,
                selected: island.context.tab,
                onSelect: actions.selectTab
            )
            .place(in: layout.tabsFrame)
            .reveal(isExpanded && island.availableTabs.count > 1, order: 0)

            WeatherBadge(report: models.weather.report)
                .place(in: layout.headerAccessoryFrame)
                .reveal(isExpanded && !showsInlineHUD && headline == nil, order: 0)

            if let headline {
                NextEventBadge(event: headline)
                    .contentShape(Rectangle())
                    .onTapGesture { actions.selectTab(.calendar) }
                    .place(in: layout.headerAccessoryFrame)
                    .reveal(isExpanded && !showsInlineHUD, order: 0)
            }

            InlineHUDView(hud: models.hud, tint: tint, hudActions: actions.hud)
                .place(in: layout.headerAccessoryFrame)
                .reveal(showsInlineHUD, order: 0)
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }
}

/// HUD, charging and banner alerts.
struct AlertContentView: View {
    let island: IslandViewModel
    let models: IslandModels
    let tint: Color
    let actions: IslandActions
    let layout: IslandLayout

    var body: some View {
        let hud = models.hud
        let hudActions = actions.hud
        let alertActions = actions.alerts
        let isAlert = island.state == .alert
        let kind = island.alert?.kind
        let shown = island.displayedAlert
        let showsHUD = isAlert && kind == .hud
        let showsPower = isAlert && kind == .power

        ZStack(alignment: .topLeading) {
            HUDGlyph(kind: hud.kind, level: hud.level, isMuted: hud.isMuted, route: hud.route)
                .place(in: layout.hudGlyphFrame)
                .reveal(showsHUD, order: 0)

            HUDLevelBar(
                kind: hud.kind,
                level: hud.level,
                isMuted: hud.isMuted,
                tint: tint,
                onChange: hudActions.setLevel,
                onInteractionChanged: hudActions.setInteracting
            )
            .place(in: layout.hudBarFrame)
            .reveal(showsHUD, order: 0)

            HUDValueLabel(level: hud.level, isMuted: hud.isMuted)
                .place(in: layout.hudValueFrame)
                .reveal(showsHUD, order: 1)

            if let power = shown?.power {
                BatteryGlyph(level: power.level, isCharging: power.isCharging, isLow: power.event == .low)
                    .place(in: layout.hudGlyphFrame)
                    .reveal(showsPower, order: 0)
                PowerValueView(alert: power)
                    .place(in: layout.alertRightWingFrame)
                    .reveal(showsPower, order: 1)
            }

            if let device = shown?.audioDevice {
                AudioDeviceBanner(alert: device)
                    .contentShape(Rectangle())
                    .onTapGesture { alertActions.activate(.audioDevice(device)) }
                    .place(in: layout.bannerFrame)
                    .reveal(isAlert && kind == .audioDevice, order: 0)
            }

            if let calendar = shown?.calendar {
                CalendarBanner(alert: calendar, onOpen: { alertActions.activate(.calendar(calendar)) })
                    .contentShape(Rectangle())
                    .onTapGesture { alertActions.activate(.calendar(calendar)) }
                    .place(in: layout.bannerFrame)
                    .reveal(isAlert && kind == .calendar, order: 0)
            }

            if let timer = shown?.timer {
                TimerBanner(alert: timer, onStop: actions.timer.stop)
                    .contentShape(Rectangle())
                    .onTapGesture { alertActions.activate(.timer(timer)) }
                    .place(in: layout.bannerFrame)
                    .reveal(isAlert && kind == .timer, order: 0)
            }

            if let screenshot = shown?.screenshot {
                ScreenshotBanner(alert: screenshot, thumbnails: models.thumbnails, actions: actions.screenshot)
                    .place(in: layout.bannerFrame)
                    .reveal(isAlert && kind == .screenshot, order: 0)
            }

            if let notification = shown?.notification {
                NotificationBanner(alert: notification)
                    .contentShape(Rectangle())
                    .onTapGesture { alertActions.activate(.notification(notification)) }
                    .place(in: layout.bannerFrame)
                    .reveal(isAlert && kind == .notification, order: 0)
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }
}

extension IslandAlert {
    var power: PowerAlert? {
        if case .power(let alert) = self { return alert }
        return nil
    }

    var audioDevice: AudioDeviceAlert? {
        if case .audioDevice(let alert) = self { return alert }
        return nil
    }

    var notification: NotificationAlert? {
        if case .notification(let alert) = self { return alert }
        return nil
    }

    var calendar: CalendarAlert? {
        if case .calendar(let alert) = self { return alert }
        return nil
    }

    var screenshot: ScreenshotAlert? {
        if case .screenshot(let alert) = self { return alert }
        return nil
    }

    var timer: TimerAlert? {
        if case .timer(let alert) = self { return alert }
        return nil
    }
}
