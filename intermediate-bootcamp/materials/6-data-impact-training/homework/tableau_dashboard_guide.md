# Tableau Dashboard Guide - Halo 5 Gaming Analytics

## Data Overview

You have 4 main datasets:

1. **matches.csv** - Match-level data (match_id, mapid, completion_date, match_duration, game_mode, etc.)
2. **match_details.csv** - Player performance per match (kills, deaths, assists, damage, rank changes, win/loss)
3. **medals.csv** - Medal definitions (medal_id, name, description, difficulty, classification)
4. **medals_matches_players.csv** - Medals earned by players per match
5. **maps.csv** - Map information (mapid, name, description)

---

## Dashboard 1: Executive Dashboard

**Audience:** Leadership/Management who need high-level KPIs

**Key Metrics to Include:**

### 1. Overall Game Health KPIs (Top Cards)
- Total matches played
- Total unique players
- Average match duration
- Overall win rate balance (how close to 50%)

### 2. Player Engagement Trends
- **Line Chart:** Matches played over time (by completion_date)
- Shows if the game is growing or declining

### 3. Top Performance Metrics
- **Bar Chart:** Top 10 players by total kills
- **Bar Chart:** Top 10 players by K/D ratio (kills/deaths)
- Shows competitive landscape

### 4. Map Popularity
- **Packed Bubbles or Treemap:** Most played maps
- Helps understand content usage

### 5. Medal Distribution
- **Horizontal Bar:** Top 10 most earned medals
- Shows what achievements players care about

### 6. Match Completion Funnel
- **Text Table or Bar:** % of matches completed vs abandoned
- Key health metric

**Design Tips:**
- Use large, clear numbers for KPIs
- Limit to 5-6 visualizations maximum
- Use consistent color scheme
- Minimal filters (maybe just date range)
- Focus on trends and summaries

---

## Dashboard 2: Exploratory Dashboard

**Audience:** Analysts, Game Designers who need to drill down

**Key Features:**

### 1. Player Performance Deep Dive
**Filters to add:**
- Player gamertag (dropdown with search)
- Date range
- Map name
- Did win (True/False)

**Visualizations:**
- **Scatter Plot:** Kills vs Deaths (colored by win/loss)
- **Line Chart:** Player rank progression over time
- **Heat Map:** Performance by map (avg kills per map)
- **Distribution:** Histogram of kills per match
- **Table:** Detailed match history with all stats

### 2. Map Analysis Section
**Visualizations:**
- **Bar Chart:** Average match duration by map
- **Stacked Bar:** Win rate by team (team_id) per map
- **Box Plot:** Kill distribution by map

### 3. Medal Analysis
**Visualizations:**
- **Bubble Chart:** Medal difficulty vs count earned (size = count)
- **Treemap:** Medals by classification
- **Bar Chart:** Average medals per match by player

### 4. Comparative Analysis
- **Parameter Controls:** Compare two players side-by-side
- **Dual Axis Chart:** Show multiple metrics over time

**Design Tips:**
- Add 5-8 filters at the top
- Use filter actions (click on chart to filter others)
- Include 8-12 visualizations organized in sections
- Add tooltips with additional details
- Use consistent color coding (e.g., blue for wins, red for losses)

---

## Step-by-Step Tableau Workflow

### Step 1: Load Data
1. Open Tableau Desktop/Public
2. Connect to Text File
3. Load all 4 CSV files
4. Create relationships:
   - matches ↔ match_details (match_id)
   - matches ↔ maps (mapid)
   - match_details ↔ medals_matches_players (match_id + player_gamertag)
   - medals ↔ medals_matches_players (medal_id)

### Step 2: Data Preparation
1. Create calculated fields:
   - **K/D Ratio:** `[player_total_kills] / [player_total_deaths]`
   - **Win Rate:** `IF [did_win] THEN 1 ELSE 0 END`
   - **Match Year-Month:** `DATETRUNC('month', [completion_date])`
   - **Rank Change:** `[spartan_rank] - [previous_spartan_rank]`

2. Verify data types:
   - Dates are recognized as dates
   - Numbers are numeric
   - IDs are strings/dimensions

### Step 3: Build Executive Dashboard
1. Create a new dashboard (1200x800 recommended size)
2. Build each sheet/visualization separately first
3. Drag sheets onto dashboard
4. Add title "Halo 5: Executive Performance Overview"
5. Add minimal filters (date range only)
6. Format for clarity (large fonts, clean layout)

### Step 4: Build Exploratory Dashboard
1. Create a new dashboard
2. Build 8-12 detailed visualizations
3. Add all filters at top or left side
4. Setup filter actions (Dashboard → Actions → Filter)
5. Add title "Halo 5: Player & Match Analysis"
6. Test interactivity

### Step 5: Publish to Tableau Public
1. File → Save to Tableau Public As...
2. Sign in to your Tableau Public account
3. Name your workbook (e.g., "Halo5_Analytics_[YourName]")
4. Wait for upload to complete
5. Copy the URL (should start with `https://public.tableau.com/views/`)

---

## Suggested Calculated Fields

```
// K/D Ratio
[player_total_kills] / IFNULL([player_total_deaths], 1)

// Damage Efficiency
[player_total_weapon_damage] / IFNULL([player_total_shots_landed], 1)

// Win Rate
AVG(IF [did_win] THEN 1.0 ELSE 0.0 END)

// Headshot Accuracy
[player_total_headshots] / IFNULL([player_total_kills], 1)

// Assists per Death
[player_total_assists] / IFNULL([player_total_deaths], 1)

// Team Player Score (high assists, low kills)
[player_total_assists] / ([player_total_kills] + 1)
```

---

## Example Insights to Highlight

1. **Executive Dashboard:**
   - "Player engagement increased 15% in Q1 2016"
   - "Top 5 maps account for 60% of all matches"
   - "Average match duration: 12.5 minutes"

2. **Exploratory Dashboard:**
   - Filter to specific players and see their progression
   - Identify which maps have highest win rate imbalance
   - Find correlation between medals earned and win rate

---

## Final Submission

Create a text file with:
```
Executive Dashboard URL: https://public.tableau.com/views/...
Exploratory Dashboard URL: https://public.tableau.com/views/...

Dashboard 1: Executive Overview
- Focus: High-level KPIs and trends
- Key Metrics: [list 3-4]

Dashboard 2: Player Analysis
- Focus: Detailed player and match exploration
- Filters: Player, Date, Map, Win/Loss
```

Zip the text file and submit!

---

## Troubleshooting Tips

- If relationships aren't working, use joins instead
- If dates aren't parsing, manually set data type
- If dashboard is slow, filter data to recent matches
- Use extracts (.hyper) instead of live connection for better performance
- Test on Tableau Public website after publishing to ensure it's accessible
