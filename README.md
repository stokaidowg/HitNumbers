# HitNumbers

Retail-style floating damage and heal numbers above whoever you hit or heal. For **OctoWoW** (the 1.12 client). It may work on Turtle WoW and other 1.12 servers, but it was only made and tried on OctoWoW.

> [!WARNING]
> **Made with AI.** This add-on was written by an AI (Claude, by Anthropic) using Claude Code. I'm not a programmer: I described what I wanted, played with it on OctoWoW, and reported problems back for the AI to fix. It has automated tests against a simulated WoW API, but some features have only been tried by me, and a few not in game at all yet, so expect bugs. Please report them under **Issues**.

## Requirements

Two OctoWoW launcher mods: **nampower** (combat events) and **ClassicAPI** (nameplates). Without them HitNumbers does nothing. Nameplates need to be on, because the numbers sit above them.

## Install

1. Download `HitNumbers.zip` from the [Releases](../../releases) page. Don't use GitHub's green **Code → Download ZIP** button: it gives a folder named `HitNumbers-main`, which WoW won't load until you rename it to `HitNumbers`.
2. Extract it into `Interface\AddOns`, so you end up with `Interface\AddOns\HitNumbers\HitNumbers.toc`.
3. Restart the game, or type `/reload` if you're already logged in.

## Usage

- `/hn test`: show some sample numbers
- `/hn on`, `/hn off`
- `/hn scale <n>`: number size
- `/hn me`: numbers on yourself on/off
- `/hn pet`: your pet's numbers on/off

## Licence

MIT, see [LICENSE](LICENSE).
