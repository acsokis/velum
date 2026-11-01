# Official integration research — 2026-10-29

Implementation status: separate offline mock adapters in `integrations.mjs`. No external account is linked; no external messages are sent. Native VELUM communication continues if services are absent. Mock disconnect clears that service's mock events. All outgoing destinations must remain explicit if live adapters are added; cross-service forwarding is prohibited by project design.

## Twitch

The official preferred combination is EventSub for receiving channel chat and the Helix Send Chat Message endpoint for sending. An installed chat client requires an app registration and authorized user access token with `user:read:chat` and `user:write:chat`; WebSocket EventSub uses user tokens. Cloud bot authorization is a different flow and may require broadcaster grants and bot-related scopes. Event subscriptions each require their own documented authorization. Streamer preview hiding and sound controls are default-off in the mock-facing UI; production credentials would require protected server-side/OS storage, revocation and refreshed OAuth handling, never browser bundles or logs.

- [Twitch chat overview](https://dev.twitch.tv/docs/chat)
- [Authentication and EventSub](https://dev.twitch.tv/docs/chat/authenticating)
- [Send and receive messages](https://dev.twitch.tv/docs/chat/send-receive-messages)

## Discord

Official Social SDK provides authorized social/game capabilities, including presence/invitations, with OAuth2 and public-client PKCE options documented for appropriate flows. SDK-enabled communication is distinct from generic access to someone's Discord client or personal inbox. Server-channel messaging requires an installed bot/application and the relevant channel permissions; installation context and OAuth scopes matter. No self-bots, scraping or user account tokens are used. Real SDK application setup, scopes, licensing/distribution terms and testing remain required before a live adapter is enabled; this milestone does not distribute the SDK.

- [Discord Social SDK](https://discord.com/developers/social-sdk)
- [SDK authentication](https://discord.com/developers/docs/slayer-sdk/authentication.html)
- [Bot scopes and installation](https://github.com/discord/discord-api-docs/blob/main/developers/quick-start/getting-started.mdx)
- [Channel permissions](https://github.com/discord/discord-api-docs/blob/main/developers/topics/permissions.mdx)
- [Self-bots are forbidden](https://support.discord.com/hc/en-us/articles/115002192352-Automated-User-Accounts-Self-Bots)

## Optional Windows integrations

Remote Desktop is a separate full-PC remote-control path. Supported hosts include Pro/Enterprise/Education/Server, not Windows Home. It is not an embeddable game companion feed and has not been enabled or integrated here. The Windows App/Remote Desktop client product transition means clients must be verified for the actual deployment rather than assuming an old app remains supported.

Phone Link requires supported platforms, accounts/connectivity and device-specific capabilities. Android Apps/phone-screen experiences are restricted to supported device/model lists; Samsung support does not imply every Samsung phone/tablet has every feature. iPhone support does not imply Android-style app/screen streaming. Nothing here relies on Phone Link or assumes unrestricted phone access.

- [Remote Desktop host requirements](https://learn.microsoft.com/en-in/windows-server/remote/remote-desktop-services/remotepc/remote-desktop-allow-access)
- [Windows remote client transition](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/windows)
- [Phone Link requirements](https://support.microsoft.com/en-us/windows/apps/phonelink/phone-link-requirements-and-setup)
- [Phone Link supported experiences/devices](https://support.microsoft.com/en-us/windows/apps/phonelink/supported-devices-for-phone-link-experiences)

The companion instead uses its own narrowly scoped synchronized state and probe JPEG endpoint over local HTTPS. Neither Remote Desktop nor Phone Link was configured, enabled or runtime-tested.
