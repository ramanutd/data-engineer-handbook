# Spotify KPIs and Experimentation - Homework Solution

## Product: Spotify

### User Journey

**Initial Discovery & Sign-Up (First Week)**
When I first discovered Spotify, I was attracted by the free tier offering and the ability to listen to almost any song I wanted. The onboarding process was smooth - I signed up using my email, and Spotify immediately asked me about my favorite artists and genres. This personalization setup made me feel like the app understood my taste from day one.

**Early Engagement (First Month)**
During my first month, I was hooked by the Discover Weekly playlist. Every Monday, I'd get a fresh playlist of songs I'd never heard before, but somehow they were always aligned with my taste. I also started using Spotify during my daily commute and workouts. The mobile app's offline mode became essential when I traveled.

**Growing Attachment (Months 2-6)**
I began creating my own playlists and following artists. The Release Radar feature kept me updated with new music from my favorite artists. I particularly loved how Spotify integrated social features - I could see what my friends were listening to and share songs directly. The seamless experience across devices (phone, laptop, smart speaker) made it indispensable.

**Long-Term Loyalty (Present Day)**
What keeps me loyal to Spotify today is the combination of its superior recommendation algorithm, the annual Spotify Wrapped feature that shows my year in music, and the extensive podcast library. The platform has become my go-to for both music and podcasts. Premium features like ad-free listening, unlimited skips, and high-quality audio make the subscription worth it. However, I've noticed competition from YouTube Music and Apple Music improving, so Spotify needs to keep innovating.

---

## Experiment 1: Enhanced Social Listening - "Listen Along" Feature

### Objective
Test whether introducing a real-time "Listen Along" feature, where users can join friends' listening sessions and hear the same songs simultaneously, increases user engagement and session duration.

### Hypothesis
**Null Hypothesis:** The "Listen Along" feature will not significantly increase daily active users (DAU) or average session duration compared to the current social features.

**Alternative Hypothesis:** Users with access to the "Listen Along" feature will show at least a 10% increase in DAU and 15% increase in average session duration compared to the control group.

### Test Cell Allocation
- **Control Group (50%):** Current Spotify experience with existing social features (friend activity feed, collaborative playlists)
- **Test Group (50%):** New "Listen Along" feature enabled, allowing users to:
  - See when friends are actively listening
  - Join their session with one tap
  - Chat within the listening session
  - Vote on next songs in the queue

### Conditions Being Tested
- **Variable:** Availability of real-time collaborative listening feature
- **Duration:** 6 weeks
- **Target Audience:** Users aged 18-35 who have at least 5 Spotify friends
- **Randomization:** User-level randomization based on user ID hash

### Metrics

**Leading Metrics (Observable within 1-2 weeks):**
- Number of "Listen Along" sessions initiated per user per week
- Click-through rate on friend activity notifications
- Number of unique friends a user listens with
- Chat messages sent during listening sessions

**Lagging Metrics (Observable after 4-6 weeks):**
- Daily Active Users (DAU) percentage change
- Average session duration (minutes per session)
- Weekly retention rate (Week 4 vs Week 1)
- Premium conversion rate for free users
- Net Promoter Score (NPS) change

**Expected Impact:**
- Leading: 30% of test group users will try the feature at least once; average 2.5 sessions per active user per week
- Lagging: 10-15% increase in session duration; 8% improvement in weekly retention

---

## Experiment 2: AI-Powered Workout Playlist Generator

### Objective
Test whether an AI-powered workout playlist generator that adapts music tempo to user's workout intensity (via integration with fitness trackers) increases workout-related listening and premium subscriptions.

### Hypothesis
**Null Hypothesis:** The AI workout playlist generator will not significantly increase workout listening hours or premium subscription conversions compared to manually created workout playlists.

**Alternative Hypothesis:** Users with access to the AI workout feature will show at least a 20% increase in workout-tagged listening hours and a 12% increase in premium conversion rate.

### Test Cell Allocation
- **Control Group (40%):** Access to existing curated workout playlists and ability to create custom workout playlists
- **Test Group A (30%):** AI workout playlist with manual intensity selection (warm-up, moderate, intense, cool-down)
- **Test Group B (30%):** AI workout playlist with automatic intensity detection via fitness tracker integration (Apple Health, Google Fit, Fitbit)

### Conditions Being Tested
- **Variables:** 
  1. AI-generated tempo-matched playlists vs. static playlists
  2. Manual intensity selection vs. automatic fitness tracker integration
- **Duration:** 8 weeks
- **Target Audience:** Users who listen to workout playlists at least twice per week
- **Randomization:** User-level randomization stratified by current subscription tier (free/premium)

### Metrics

**Leading Metrics (Observable within 1-2 weeks):**
- Feature adoption rate (% of users who try AI workout playlist)
- Number of AI workout sessions per user per week
- Fitness tracker connection rate (Test Group B only)
- Average workout session completion rate
- User rating of workout playlist quality (in-app feedback)

**Lagging Metrics (Observable after 4-8 weeks):**
- Total workout-tagged listening hours per user
- Premium subscription conversion rate for free users
- Churn rate for premium users
- Monthly recurring revenue (MRR) change
- User satisfaction score for workout experience

**Expected Impact:**
- Leading: 45% adoption rate in test groups; 3.5 workout sessions per user per week; 60% fitness tracker connection rate in Group B
- Lagging: 20-25% increase in workout listening hours; 12-15% increase in premium conversions; 5% reduction in churn

---

## Experiment 3: Dynamic Pricing for Premium Family Plan

### Objective
Test whether offering a flexible family plan pricing structure based on the number of members (2-6 members) instead of a fixed price for up to 6 members increases family plan subscriptions and overall revenue.

### Hypothesis
**Null Hypothesis:** Dynamic pricing for family plans will not significantly increase family plan subscription revenue compared to the current fixed-price model.

**Alternative Hypothesis:** Dynamic pricing will increase family plan subscriptions by at least 18% and total family plan revenue by at least 15% due to lower barrier to entry for smaller households.

### Test Cell Allocation
- **Control Group (50%):** Current family plan pricing ($16.99/month for up to 6 members)
- **Test Group (50%):** Dynamic pricing structure:
  - 2 members: $12.99/month
  - 3 members: $14.99/month
  - 4 members: $16.99/month
  - 5-6 members: $18.99/month

### Conditions Being Tested
- **Variable:** Pricing structure (fixed vs. dynamic based on family size)
- **Duration:** 12 weeks (3 months to capture full billing cycles)
- **Target Audience:** 
  - New users considering family plan
  - Current individual premium subscribers with 2+ household members
  - Current family plan subscribers (grandfathered into existing price)
- **Randomization:** Geographic randomization by region to avoid household conflicts

### Metrics

**Leading Metrics (Observable within 2-4 weeks):**
- Family plan signup page visit rate
- Pricing page interaction time
- Add family member click-through rate
- Shopping cart abandonment rate
- Customer support inquiries about pricing

**Lagging Metrics (Observable after 8-12 weeks):**
- Total family plan subscriptions (new signups)
- Family plan conversion rate from individual plans
- Total family plan revenue
- Average revenue per family plan user (ARPU)
- Family plan churn rate
- Customer satisfaction score (CSAT) for pricing fairness

**Expected Impact:**
- Leading: 25% increase in family plan signup page conversions; 40% reduction in cart abandonment; 30% increase in individual-to-family plan upgrades
- Lagging: 18-22% increase in family plan subscriptions; 15-20% increase in total family plan revenue; ARPU of $15.50 for test group vs. $16.99 for control (offset by volume); 3% improvement in retention

---

## Summary

These three experiments target different aspects of Spotify's growth and retention strategy:

1. **Enhanced Social Listening** focuses on increasing engagement through social features, which can improve stickiness and word-of-mouth growth
2. **AI Workout Playlists** addresses a specific use case to drive premium conversions and partnerships with fitness tracking platforms
3. **Dynamic Family Pricing** optimizes monetization by reducing barriers to entry for smaller households while potentially increasing revenue from larger ones

Each experiment has clear success metrics, proper control and test groups, and realistic timelines for measurement. The combination of leading and lagging metrics ensures we can detect early signals while also measuring long-term business impact.
