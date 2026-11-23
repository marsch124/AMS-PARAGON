# Round 365: count on Mine

Before: the Who row on All actions had one box, "Mine" (no number).
Now: the box reads "Mine 12" (word, space, number, same pattern as the header's "Actions 12"). Identifier stays `actions.box.who.mine`. Spoken label: "Mine, 12 tasks, ticked" or "not ticked" ("Mine, 1 task" for one). Zero reads "Mine 0". The filter summary line still says "Mine".

Counting rule: the open actions that would be listed if Mine were ticked, with every other box and the search words as they are now; ticked or not, the number is the same and equals the rows shown. With no name set the number is 0 (the row is hidden then anyway).

Code: `ActionFilter.mineCount(among:me:today:matching:)` in Core; `FilterBox` got an optional `spoken` text; the box title is built in AllActionsView.

Uncertain: the header's "Actions 12" ignores the search words, but Mine counts them (so it equals the rows listed). Mine can therefore differ from the header number while he is searching on the iPhone. No screen test matched the Mine box (none exists), nothing adjusted.

(a) What's new: The Mine box on All actions now shows how many actions are yours, right beside the word, for example "Mine 12". The number follows your other boxes and search, so it is exactly what you see after ticking it.
(b) How it works: In All actions, the Mine box shows its number next to its name. It counts the open actions with your name or no name that fit the other boxes you have ticked and your search. "Mine 0" means none are yours right now.
