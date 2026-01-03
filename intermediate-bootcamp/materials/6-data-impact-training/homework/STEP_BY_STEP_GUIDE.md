# Step-by-Step Guide to Create Tableau Dashboards for Homework

## STEP 1: Download and Install Tableau Public (if you don't have it)
1. Go to: https://public.tableau.com/en-us/s/download
2. Download Tableau Public (it's free)
3. Install and create an account

---

## STEP 2: Open Tableau and Load Data

1. **Open Tableau Public**

2. **Connect to your first CSV file:**
   - On the left side, under "Connect", click **"Text file"**
   - Navigate to: `/Users/raman/workspace/dataexpert.io/bootcamp-community-edition-2025/data-engineer-handbook/intermediate-bootcamp/materials/3-spark-fundamentals/data/`
   - Select **matches.csv**
   - Click "Open"

3. **Add the other CSV files:**
   - You'll see "matches" table appear in the middle
   - Look for "Add" (usually near the top or drag a "New Union" option)
   - Click the small icon next to "Connections" on the left
   - Select "Text file" again
   - Add **match_details.csv**
   - Repeat to add **medals.csv**
   - Repeat to add **medals_matches_players.csv**
   - Repeat to add **maps.csv**

4. **Create relationships between tables:**
   - You should see all 5 tables listed
   - Drag **match_details** near **matches** - a line will appear
   - Click the line/relationship
   - Set: `match_id` = `match_id`
   - Drag **maps** near **matches**
   - Click the relationship, set: `mapid` = `mapid`
   - Drag **medals_matches_players** near **match_details**
   - Click relationship, add two conditions:
     - `match_id` = `match_id` AND
     - `player_gamertag` = `player_gamertag`
   - Drag **medals** near **medals_matches_players**
   - Click relationship, set: `medal_id` = `medal_id`

5. **Click "Sheet 1" tab at the bottom** (you're now ready to create visualizations!)

---

## STEP 3: Create Dashboard 1 - Executive Dashboard

### Chart 1: Total Matches (Big Number)
1. Create new sheet (click + icon next to Sheet 1)
2. Rename sheet: "Total Matches"
3. Drag **Match Id** (from Matches table) to the main area
4. Change it to **COUNTD** (right-click → Measure → Count Distinct)
5. Click the "Show Me" panel (top right) → select "Text table"
6. Make the number BIG (format → font → 36+)

### Chart 2: Matches Over Time
1. Create new sheet: "Matches Over Time"
2. Drag **Completion Date** to Columns
3. Change to Month or Week (click the date pill → Month)
4. Drag **Match Id** to Rows
5. Change to COUNTD (right-click → Measure → Count Distinct)
6. This creates a line chart showing matches over time

### Chart 3: Top Players by Kills
1. Create new sheet: "Top Players Kills"
2. Drag **Player Gamertag** (from Match Details) to Rows
3. Drag **Player Total Kills** to Columns
4. Right-click Player Total Kills → Measure → Sum
5. Sort descending (click sort icon in toolbar)
6. Right-click Player Gamertag → Filter → Top 10 by Player Total Kills

### Chart 4: Most Played Maps
1. Create new sheet: "Popular Maps"
2. Drag **Name** (from Maps table) to Rows
3. Drag **Match Id** to Columns
4. Change to COUNTD
5. Sort descending
6. Keep top 10

### Chart 5: Win Rate Distribution
1. Create new sheet: "Win Rate"
2. Drag **Did Win** to Columns
3. Drag **Match Id** to Rows
4. Change to COUNTD
5. Show Me → Pie Chart
6. Add labels (right-click chart → Add Label)

### Combine into Dashboard 1:
1. Click Dashboard → New Dashboard (bottom tab)
2. Rename: "Executive Dashboard"
3. Drag each of the 5 sheets onto the dashboard
4. Arrange them nicely (Total Matches at top as big number)
5. Add title: "Halo 5 - Executive Overview"

---

## STEP 4: Create Dashboard 2 - Exploratory Dashboard

### Chart 1: Player Performance - Kills vs Deaths
1. Create new sheet: "Kills vs Deaths"
2. Drag **Player Total Deaths** to Columns
3. Drag **Player Total Kills** to Rows
4. Drag **Did Win** to Color (makes different colors for wins/losses)
5. This creates a scatter plot

### Chart 2: Player Stats by Map
1. Create new sheet: "Performance by Map"
2. Drag **Name** (from Maps) to Rows
3. Drag **Player Total Kills** to Columns (as SUM)
4. Show as bar chart

### Chart 3: Top Medals Earned
1. Create new sheet: "Top Medals"
2. Drag **Name** (from Medals table) to Rows
3. Drag **Count** (from Medals Matches Players) to Columns
4. Change Count to SUM
5. Sort descending (click sort icon)
6. Right-click Name → Filter → Top 15 by Sum of Count
7. Add **Classification** (from Medals) to Color for visual interest
8. This shows which achievements players earn most - fast and colorful!

### Combine into Dashboard 2 with Filters:
1. Click Dashboard → New Dashboard
2. Rename: "Exploratory Dashboard"
3. Drag the 3 sheets onto dashboard
4. Add filters (TWO WAYS):
   
   **METHOD 1 - From any chart on the dashboard:**
   - Click on one of your charts in the dashboard
   - You'll see a small dropdown arrow appear in the top-right corner of the chart
   - Click the dropdown arrow → More Options → Filters → [select field]
   - Check: Player Gamertag, Completion Date, Name (map)
   
   **METHOD 2 - Simpler way:**
   - Look at the left sidebar (where you dragged sheets from)
   - You'll see dimensions listed (Player Gamertag, Completion Date, Name, etc.)
   - Drag **Player Gamertag** onto the dashboard (it becomes a filter!)
   - Drag **Completion Date** onto the dashboard
   - Drag **Name** (from Maps) onto the dashboard
   - The filters will appear where you drop them
   
5. Arrange filters on left or top
6. Add title: "Halo 5 - Player Analysis"

---

## STEP 5: Publish to Tableau Public

1. **Save your work first:**
   - File → Save to Tableau Public As...
   - Sign in with your Tableau Public account
   - Name it: "Halo5_Homework_YourName"
   - Wait for upload (may take a few minutes)

2. **After publishing:**
   - Tableau will open a web browser
   - You'll see your dashboards online
   - Copy the URL from browser (should be like: `https://public.tableau.com/views/Halo5_Homework_YourName/ExecutiveDashboard`)

3. **Get both dashboard URLs:**
   - Click on "Executive Dashboard" tab → copy URL
   - Click on "Exploratory Dashboard" tab → copy URL

---

## STEP 6: Create Submission File

1. Open a text editor
2. Create a file called `tableau_links.txt`
3. Add:
```
Executive Dashboard URL: [paste URL 1 here]
Exploratory Dashboard URL: [paste URL 2 here]

Dashboard 1: Executive Overview
- Total matches played
- Matches over time trend
- Top 10 players by kills
- Most popular maps
- Win/loss distribution

Dashboard 2: Exploratory Analysis with Filters
- Player gamertag filter
- Date range filter
- Map filter
- Kills vs Deaths scatter plot
- Performance by map
- Detailed match data table
```

4. Save the file
5. Zip the file: Right-click → Compress "tableau_links.txt"
6. Submit the zip file

---

## TROUBLESHOOTING

**Problem: Can't see data after loading CSVs**
- Solution: Make sure you created relationships, not joins

**Problem: Charts are empty**
- Solution: Check that you're using the right measure (SUM, COUNTD, etc.)

**Problem: Too much data, Tableau is slow**
- Solution: Add a date filter to limit to recent matches only

**Problem: Can't publish - file too large**
- Solution: Use Data → Extract Data to create a smaller file

**Problem: Dashboard URL doesn't start with "https://public.tableau.com/views/"**
- Solution: Make sure you used "Save to Tableau Public As..." not regular Save

---

## DONE!
Once you have your two URLs and submit the zip file, you're finished!
