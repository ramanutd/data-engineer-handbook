# Week 5 Data Pipeline Maintenance - Solution

## Team Structure & Pipeline Ownership

### Team Members
- **Engineer A** (Alice)
- **Engineer B** (Bob)
- **Engineer C** (Carol)
- **Engineer D** (David)

### Pipeline Ownership Matrix

| Pipeline | Business Area | Primary Owner | Secondary Owner | Backup |
|----------|---------------|---------------|-----------------|---------|
| Unit-Level Profit Pipeline | Profit (Experiments) | Alice | Bob | Carol |
| Aggregate Profit Pipeline | Profit (Investors) | Bob | Alice | David |
| Aggregate Growth Pipeline | Growth (Investors) | Carol | David | Alice |
| Daily Growth Pipeline | Growth (Experiments) | David | Carol | Bob |
| Aggregate Engagement Pipeline | Engagement (Investors) | Alice | Carol | David |

### Ownership Rationale

**Profit Domain:**
- Alice and Bob are paired together as they handle related profit metrics
- Having the same engineers own both unit-level and aggregate ensures consistency in business logic
- Alice (primary on unit-level) and Bob (primary on aggregate) can cross-validate each other's work

**Growth Domain:**
- Carol and David are paired as the growth domain experts
- Similar to profit, this ensures consistency between experiment and investor-facing metrics

**Engagement Domain:**
- Alice as primary (also owns unit-level profit for experiments)
- Carol as secondary (brings growth perspective to engagement metrics)

---

## On-Call Schedule

### Schedule Overview
- **Rotation Type:** Weekly rotation with 24/7 coverage
- **Schedule Duration:** 4-week cycles
- **Primary/Secondary Model:** Always have a primary and secondary on-call

### Standard 4-Week Rotation

| Week | Primary On-Call | Secondary On-Call | Notes |
|------|-----------------|-------------------|-------|
| Week 1 | Alice | Bob | Regular rotation |
| Week 2 | Bob | Carol | Regular rotation |
| Week 3 | Carol | David | Regular rotation |
| Week 4 | David | Alice | Regular rotation |

### Holiday Schedule Considerations

**Major Holidays (U.S. Calendar):**
- New Year's (Dec 31 - Jan 2)
- Memorial Day (Late May)
- Independence Day (July 4)
- Labor Day (Early September)
- Thanksgiving (Late November)
- Christmas (Dec 24-26)

**Holiday Rotation Rules:**
1. **Voluntary First:** Always ask for volunteers first
2. **Fair Distribution:** No engineer should be on-call for more than 2 major holidays per year
3. **Holiday Swaps:** Engineers can trade shifts with advance notice (72 hours minimum)
4. **Holiday Compensation:** Engineers on-call during major holidays receive:
   - 1.5x compensation for the holiday period
   - Guaranteed comp day within the following month
   - Flexible shift during the holiday (4-hour check-ins rather than constant monitoring)

**Sample Holiday Schedule (Year View):**

| Holiday Period | Primary | Secondary | Compensation |
|----------------|---------|-----------|--------------|
| Q1 - New Year's | David (volunteer) | Alice | +1.5 days comp |
| Q2 - Memorial Day | Bob | Carol | +1 day comp |
| Q3 - July 4th | Carol (volunteer) | David | +1 day comp |
| Q3 - Labor Day | Alice | Bob | +1 day comp |
| Q4 - Thanksgiving | David | Alice | +1.5 days comp |
| Q4 - Christmas | Bob (volunteer) | Carol | +1.5 days comp |

### On-Call Responsibilities

**Primary On-Call:**
- First responder to all alerts
- Response time: 15 minutes for P0/P1, 1 hour for P2
- Responsible for incident resolution or escalation
- Post-incident reports and documentation
- Proactive monitoring checks (daily)

**Secondary On-Call:**
- Backup for primary (if unreachable after 30 minutes)
- Code review for emergency fixes
- Assists with complex incidents
- Takes over if primary is overwhelmed with multiple incidents

### On-Call Handoff Process
1. **Monday 10 AM (local time):** Synchronous handoff meeting
2. **Handoff includes:**
   - Review of previous week's incidents
   - Current system health status
   - Upcoming deployments or known risks
   - Any ongoing investigations
3. **Documentation:** Updated handoff document in shared wiki

---

## Runbooks for Investor-Facing Pipelines

### 1. Aggregate Profit Pipeline Runbook

**Pipeline Overview:**
- **Purpose:** Reports total company profit to investors quarterly/monthly
- **Owner:** Bob (Primary), Alice (Secondary)
- **SLA:** Must complete by 8 AM EST on reporting day
- **Criticality:** P0 - Revenue impacting

**Architecture:**
```
Source Systems → Data Lake → Transformation → Aggregate Profit Table → BI Dashboard
(Stripe, Banks)   (S3)      (dbt/Airflow)    (Snowflake)            (Tableau)
```

**Potential Issues & Detection:**

| Issue | Symptoms | Detection Method | Impact Level |
|-------|----------|------------------|--------------|
| Missing payment data from Stripe | Row count < expected threshold | Data quality check: `SELECT COUNT(*) FROM payments WHERE date = CURRENT_DATE` | P0 |
| Currency conversion failure | NULL values in USD_amount column | `SELECT COUNT(*) WHERE usd_amount IS NULL` | P0 |
| Late-arriving data | Data not available by 6 AM cutoff | Airflow sensor timeout | P1 |
| Duplicate transactions | Sum of profit > expected variance | `SELECT transaction_id, COUNT(*) HAVING COUNT(*) > 1` | P0 |
| Cost data missing | Costs = 0 for any date | `SELECT date WHERE total_costs = 0` | P0 |
| Refund processing error | Refunds not subtracted from profit | Compare refund_amount from source vs. final profit | P1 |
| Historical data changed | Previous period profit changed > 5% | Compare current run to previous snapshot | P1 |

**Key Metrics to Monitor:**
- Total profit vs. previous period (expected variance: ±10%)
- Number of transactions processed
- Profit margin percentage (expected range: 15-25%)
- Data freshness (max 24 hours old)

**Dependencies:**
- Stripe API (external)
- Banking data feeds (external)
- Currency conversion API (external)
- Cost allocation pipeline (internal)

**Emergency Contacts:**
- Finance Team: finance-team@company.com
- Stripe Account Manager: account-mgr@stripe.com
- Database Admin: dba-oncall@company.com

---

### 2. Aggregate Growth Pipeline Runbook

**Pipeline Overview:**
- **Purpose:** Reports user/revenue growth metrics to investors
- **Owner:** Carol (Primary), David (Secondary)
- **SLA:** Must complete by 9 AM EST daily
- **Criticality:** P0 - Growth metrics for board reporting

**Architecture:**
```
User Events → Event Stream → Growth Metrics ETL → Growth Tables → Dashboard
(App/Web)     (Kafka)       (Spark/Airflow)     (Postgres)     (Looker)
```

**Potential Issues & Detection:**

| Issue | Symptoms | Detection Method | Impact Level |
|-------|----------|------------------|--------------|
| Event stream lag | Kafka consumer lag > 1 hour | Monitor Kafka consumer group lag | P0 |
| Bot traffic not filtered | Spike in new users > 3σ | Anomaly detection on daily user growth | P1 |
| Attribution logic broken | Source = NULL for > 5% of users | `SELECT COUNT(*) WHERE source IS NULL` | P1 |
| Duplicate user counting | MAU/DAU ratio abnormal | Compare user counts across different aggregation levels | P0 |
| Timezone handling error | Daily metrics show wrong day boundaries | Verify UTC conversion logic | P2 |
| Missing cohort data | Cohort retention = 0 for recent cohorts | `SELECT cohort_date, retention_rate FROM cohorts WHERE retention_rate = 0` | P1 |
| Revenue growth mismatch | Growth revenue ≠ profit revenue | Cross-check with profit pipeline | P0 |

**Key Metrics to Monitor:**
- Daily Active Users (DAU) - expected range based on weekly average
- Monthly Active Users (MAU)
- New user signups (expected: weekday > weekend)
- DAU/MAU ratio (healthy: 0.15-0.25)
- Revenue growth % (month-over-month)

**Dependencies:**
- Event tracking system (Segment/mParticle)
- Kafka cluster
- User database
- Revenue/transaction database

**Emergency Contacts:**
- Product Analytics Team: product-analytics@company.com
- Engineering Platform: platform-oncall@company.com
- Marketing Team (for attribution): marketing@company.com

---

### 3. Aggregate Engagement Pipeline Runbook

**Pipeline Overview:**
- **Purpose:** Reports user engagement metrics to investors and executive team
- **Owner:** Alice (Primary), Carol (Secondary)
- **SLA:** Must complete by 10 AM EST daily
- **Criticality:** P0 - Key product health indicator

**Architecture:**
```
Event Data → Data Warehouse → Engagement ETL → Engagement Tables → Reporting
(Kafka/S3)   (BigQuery)       (dbt models)    (BigQuery)         (Mode/Tableau)
```

**Potential Issues & Detection:**

| Issue | Symptoms | Detection Method | Impact Level |
|-------|----------|------------------|--------------|
| Event schema changes | Pipeline failures due to missing columns | Schema validation in CI/CD | P0 |
| Session calculation broken | Avg session duration = 0 or NULL | `SELECT AVG(session_duration) FROM sessions WHERE date = CURRENT_DATE` | P1 |
| Feature usage not tracked | All feature columns = 0 | Row-level checks on feature engagement | P1 |
| Mobile vs. web split wrong | Mobile users = 0 | `SELECT platform, COUNT(*) GROUP BY platform` | P2 |
| Engagement spike from bots | Engagement per user > 10σ from mean | Anomaly detection on per-user metrics | P1 |
| Cohort degradation logic error | New cohorts show 100% retention | Validate retention calculation logic | P1 |
| Time-on-site calculation broken | Negative time values present | `SELECT COUNT(*) WHERE time_on_site < 0` | P2 |
| Missing weekend data | No data for Saturday/Sunday | Check data completeness for all days of week | P0 |

**Key Metrics to Monitor:**
- Average session duration (expected: 5-15 minutes)
- Sessions per user (expected: 2-5 per day for active users)
- Feature adoption rate (% of users using key features)
- Content engagement rate
- Push notification engagement rate
- Email open rate (if applicable)

**Dependencies:**
- Event tracking infrastructure
- Session service
- User profile database
- Feature flag system
- Notification service

**Emergency Contacts:**
- Product Team: product-team@company.com
- Engineering: eng-oncall@company.com
- Data Platform: data-platform@company.com
- Mobile Team (for mobile-specific issues): mobile-eng@company.com

---

## General Incident Response Framework

### Severity Levels

| Severity | Description | Response Time | Example |
|----------|-------------|---------------|---------|
| P0 | Investor metrics wrong/missing on reporting day | 15 minutes | Aggregate profit wrong day before board meeting |
| P1 | Pipeline failure affecting next day's report | 1 hour | Daily growth pipeline fails, will impact tomorrow's report |
| P2 | Data quality issue with workaround available | 4 hours | Some data missing but can be backfilled |
| P3 | Minor issues not affecting reporting | Next business day | Documentation outdated |

### Incident Response Steps

1. **Acknowledge** (within SLA response time)
   - Check monitoring dashboard
   - Acknowledge alert in PagerDuty/OpsGenie
   - Post in #data-incidents Slack channel

2. **Assess** (5-10 minutes)
   - Determine severity
   - Identify affected pipelines and downstream systems
   - Check if data is needed for imminent reporting

3. **Communicate** (within 15 minutes of acknowledgment)
   - Notify stakeholders based on severity
   - Post status in #data-incidents
   - For P0/P1: Notify leadership and affected business teams

4. **Mitigate** (time-boxed based on severity)
   - Attempt quick fix
   - If no quick fix: implement workaround
   - Document actions taken

5. **Resolve** 
   - Fix root cause
   - Verify data accuracy
   - Run validation queries
   - Update stakeholders

6. **Post-Mortem** (for P0/P1 incidents)
   - Schedule within 48 hours of resolution
   - Document timeline, root cause, and action items
   - Identify prevention measures

---

## Communication Protocols

### Stakeholder Communication Matrix

| Incident Severity | Stakeholders to Notify | Communication Channel | Frequency |
|-------------------|------------------------|----------------------|-----------|
| P0 | C-suite, Finance, Board members, Data team | Email + Slack + Phone | Immediate + Every 30 min |
| P1 | VP of Data, Finance, Product leads | Slack + Email | Immediate + Hourly |
| P2 | Data team, Affected product teams | Slack | At start and resolution |
| P3 | Data team only | Slack or ticket | As needed |

### Message Templates

**P0 Incident:**
```
URGENT: [Pipeline Name] Incident - [Affected Metric]

Status: INVESTIGATING/IDENTIFIED/MITIGATING/RESOLVED
Impact: [Describe what metrics/reports are affected]
Timeline: [When will this be resolved]
Workaround: [If available]
Next Update: [When you'll provide next update]

Primary: [Your name]
Incident Link: [Link to incident tracking]
```

---

## Monitoring & Alerting Strategy

### Alert Criteria

**Data Quality Alerts:**
- Row count deviation > 20% from 7-day average
- NULL values in critical columns > 1%
- Duplicate records detected
- Data freshness > SLA threshold

**Pipeline Health Alerts:**
- Job failure
- Job duration > 2x historical average
- Job not started within expected window
- Downstream dependency failure

**Business Metric Alerts:**
- Metric value > 3σ from historical trend
- Day-over-day change > 30%
- Missing data for any reporting segment

### On-Call Best Practices

1. **Proactive Monitoring:**
   - Review dashboards at start of shift
   - Check for warnings (not just errors)
   - Review scheduled jobs for the day

2. **Documentation:**
   - Update runbooks after each incident
   - Document any manual interventions
   - Keep handoff notes current

3. **Prevention:**
   - Schedule time for tech debt reduction
   - Implement automated tests after incidents
   - Regular chaos engineering drills

4. **Work-Life Balance:**
   - Don't work on non-urgent items during on-call
   - Take breaks between incidents
   - Use secondary for code review of emergency fixes
   - No deployments without approval during on-call

---

## Appendix: Quick Reference

### Common Issues & Quick Fixes

**Issue:** Data not showing in dashboard
**Quick Check:** `SELECT MAX(date) FROM [table]` - verify latest data date
**Fix:** Re-run pipeline for missing date

**Issue:** Pipeline failing with timeout
**Quick Check:** Check cluster resources and query runtime
**Fix:** Scale up compute resources temporarily

**Issue:** Duplicate data
**Quick Check:** `SELECT date, COUNT(*) GROUP BY date HAVING COUNT(*) > 1`
**Fix:** Delete and re-run for affected dates

**Issue:** Wrong date range in aggregation
**Quick Check:** Verify timezone and date logic in transformation
**Fix:** Update date filter and re-run

### Useful Queries

```sql
-- Check data freshness
SELECT 
    table_name,
    MAX(updated_at) as last_update,
    DATEDIFF(hour, MAX(updated_at), CURRENT_TIMESTAMP()) as hours_old
FROM information_schema.tables
WHERE table_schema = 'analytics'
GROUP BY table_name;

-- Check for anomalies in daily metrics
SELECT 
    date,
    metric_value,
    AVG(metric_value) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) as avg_7d,
    STDDEV(metric_value) OVER (ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) as stddev_7d
FROM daily_metrics
WHERE date >= CURRENT_DATE - 30
ORDER BY date DESC;

-- Find duplicate records
SELECT 
    date,
    user_id,
    COUNT(*) as duplicate_count
FROM fact_table
GROUP BY date, user_id
HAVING COUNT(*) > 1;
```

### Escalation Contacts

| Role | Contact | When to Escalate |
|------|---------|------------------|
| VP of Data | vpdata@company.com | P0 incidents not resolved in 2 hours |
| CTO | cto@company.com | Multi-pipeline P0 lasting > 4 hours |
| CFO | cfo@company.com | Financial data incorrect before board meeting |
| Database Admin | dba-oncall@company.com | Infrastructure/database issues |
| Cloud Platform | cloud-support@company.com | AWS/Cloud infrastructure issues |

---

## Summary

This data pipeline maintenance plan ensures:

1. **Clear Ownership:** Each pipeline has defined primary and secondary owners with expertise alignment
2. **Fair On-Call Distribution:** Rotating schedule with holiday considerations and compensation
3. **Comprehensive Runbooks:** Detailed documentation of potential issues, detection methods, and impact
4. **Rapid Response:** Clear severity levels and response protocols
5. **Stakeholder Communication:** Templates and protocols for keeping business partners informed
6. **Continuous Improvement:** Post-mortem process and documentation updates

The plan balances operational excellence with engineer well-being while maintaining the high reliability required for investor-facing metrics.
