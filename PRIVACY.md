# Trove — Privacy Policy

Last updated: 2026-09-05

Trove is a personal gear inventory app. It has no accounts and no sign-up:
there is nothing to log into, and nothing about you is collected, profiled or
sold. Your collection lives on your device, and — if you are signed into
iCloud — in your own private iCloud database, which only you can read. Apart
from Apple's own iCloud sync, Trove talks to exactly one outside service,
Reverb, and only when you ask it to.

## What Trove stores, and where

Everything you enter lives in the app's own store on your device. Most of it
syncs across your devices through your private iCloud database when you are
signed in; the market figures Trove fetches from Reverb deliberately do not.

| What | Where | Syncs? |
|---|---|---|
| Your owned items and wishlist items — names, categories, prices, dates, conditions, notes, ratings | on your device | yes, to your private iCloud database |
| Your photos of your items | on your device | yes, to your private iCloud database |
| Your own value for an item, adopted or typed | on your device | yes, to your private iCloud database |
| The match — the Reverb product identifier you picked for an item | on your device | yes, to your private iCloud database |
| The item's year, when you give one | on your device | yes, to your private iCloud database |
| The last figure for a matched item — median, low, high, count, when it was fetched, the year it narrowed to, and the trimmed range the value slider runs between | on your device | no |
| The matched product's catalog slug and title, so the link back to Reverb works without another request | on your device | no |
| The history of figures for a matched item | on your device | no |
| Anything from an individual listing — its title, seller, image or listing identifier | nowhere; it is never stored | — |

A matched item's history is kept for as long as the match exists. Removing the
match, or changing it to a different product, deletes that item's figure and
its history. Deleting an item deletes everything Trove held about it.

## What leaves your device

> Finding a match sends this item’s name to Reverb — nothing else about it. Refreshing later sends only which product it is — your item’s details stay on this device.

That is the whole of it, in detail:

- **Searching for a match** sends the text you search for — by default your
  item's name — to Reverb, so it can return candidate products.
- **Refreshing a figure** sends the identifier of the product you matched, and
  nothing about your item: not its condition, not its year, not what you paid,
  not what it is worth to you, not your notes, not your photos. The condition
  and the year are applied here on your device, to the listings after they
  arrive.
- Each request carries the app's name, its version and the contact address
  below as its `User-Agent`, because Reverb's API terms ask for a way to reach
  the developer.
- Nothing is sent on launch, in the background, or without you tapping
  something. No image ever leaves the app.

## Reverb

Reverb is where the asking prices come from. What Reverb does with a search or
a product request is governed by Reverb's own privacy policy, not this one.

> This application uses the Reverb API but is not endorsed, created by or certified by Reverb.com, LLC.

Of what Reverb returns, Trove keeps only the summary numbers described above —
a median, a low, a high, a count, a timestamp — plus the matched product's
slug and title for the link back. It never stores a listing's title, its
seller, its image or its identifier, and it never combines your items with one
another or with anyone else's.

## iCloud

If you are signed into iCloud, your synced data travels through your own
private iCloud database using Apple's CloudKit. Apple's iCloud terms and
privacy policy govern that. The developer of Trove cannot see it. The market
figures, history and catalog snapshot never sync — they stay on the device
that fetched them, so a second device builds its own.

## Nothing else

No accounts. No analytics. No advertising, and no ad identifiers. No
third-party SDKs of any kind — Trove is built on Apple frameworks only. No
crash reporting of the app's own, beyond whatever you have chosen to share
with Apple in iOS's own settings.

## Contact

Questions about this policy, or about the app:
[canadianfishturkey@gmail.com](mailto:canadianfishturkey@gmail.com)

## Changes

This file lives in Trove's repository, and the repository's history is the
record of every change made to it. The app links to this exact file.
