# Changelog

## 0.4.0

- **Every order tab:** the cards now show on Personal and Guild orders too, and on Public orders once you pick an item. Personal and guild cards show the customer and their note, and the Public tab shows how many claims you have left today.
- **Order queue:** press **+** on a card (or right-click it) to queue it, or **Queue all** for every profitable order on the board. Chat says why any were left out: not learned, at a loss, not enough concentration, no claims left. The queue sits beside the profession window, one row per order, with its own button: **Claim**, **Craft**, then **Hand in**. **Next** does the next step of the first order that's ready, so a whole queue goes by one button.
- **Craft uses the planned materials:** the cheapest quality that reaches what the customer asked for, the best quality when it's needed, and concentration only when the plan needs it. Just before crafting it checks again that the quality is still reached, and the button says what's missing when you're short of materials or away from your crafting table.
- **Shopping list:** everything the queued orders still need, counted once across the queue (what you own counts once, not per order), with prices. It opens anywhere, at the Auction House too. With **Auction Coach** installed, one button adds it to Auction Coach's shopping list, which tells you when each item is listed cheaply (needs Auction Coach 0.15). With **Auctionator**, one button makes an Auctionator shopping list.
- **Minimap button:** left-click for the options, right-click for the shopping list, Shift-click to show or hide the queue. `/pp minimap` hides it.
- **What things are worth to you:** a **Values** button above the cards.
  - **Concentration:** say what a point is worth in gold and orders that need it have that taken off their profit, since you can't spend it on another craft. Best, Profit and the Profitable filter all use the profit after it.
  - **Rewards without a price:** Moxie, knowledge and payout bags each get a box, and the value is added to the reward. Moxie has an **Estimate** button: what a Master's Surplus bag holds at today's prices, per Moxie.
- **Smarter numbers:**
  - Reward items are valued after the 5% AH cut, since that's what you'd get selling them.
  - The first craft of a recipe pays 10 extra Moxie, now counted.
  - Ingenuity's average refund is taken off the concentration an order costs.
  - Auction Coach is now a price source, used first when it's installed.
- **Values** and **Queue Orders** stand out in gold above the cards, so they're easy to spot.
- **Fixed:** the top border of the buttons above the cards, and the right border of the last filter, could go missing at some UI scales. Their borders are now always exactly one screen pixel.
- **Fixed:** some orders said *Any quality* when the customer had asked for one. Materials that don't come in qualities were sent along when asking the game which quality you'd reach, and the game then gave no answer. They're left out now, and when the game still can't say, the card says *Not sure* instead of guessing.

## 0.2.2

- **Fixed:** after crafting an order (most often with another crafting addon open), the cards could all disappear until you searched again. The game empties its order list for a moment while it fetches a new one, and Patron Planner was redrawing from that empty list. Now the cards stay until the new list arrives, and the board reads the list again when you come back from an order.

## 0.2.1

- **Fixed:** the last filter button (Unlearned) lost its right border when the row was too wide for the window. The buttons now tighten up to fit.

## 0.2.0

- **Materials you already own:** Patron Planner checks your bags, bank, reagent bank and warband bank. A material's count turns green when you have enough and amber when you have some, the card says how much is left to buy, and orders you can fill entirely from stock say "All in your bags".
- **Nothing to buy filter:** the orders you can craft without buying anything, because the patron supplies it all or you already own it.
- **Gold per concentration:** orders that need concentration show the profit per concentration point, and the new "Per concentration" sort puts the best use of your concentration first.
- **Options page** (Esc > Options > AddOns, or `/pp options`): price source, count materials you own as free, show silver and copper, start in Blizzard's list, and when time left turns amber.
- **Fixed:** a filter button could lose its left border at some UI scales.
- **Updated for patch 12.1.5.**

## 0.1.0

- Card view for the Patron tab of Crafting Orders: one card per order with the profit, quality needed and how to reach it, time left, what you supply and what you get.
- Summary bar: order count, how many you can craft, total profit on offer and your concentration.
- Filters: All, Can craft, Profitable, No concentration, Bonus rewards, Unlearned.
- Sort by Best, Profit, Reward or Time left.
- Hover a card for the full breakdown, hold Shift for the item, click to open the order.
- Recipes you haven't learned are greyed out at the bottom, with how to learn them.
- Prices from TradeSkillMaster or Auctionator when installed.
- "Classic list" button to switch back to Blizzard's list at any time.
