-- target_base for merchant 501, October 2026, Diwali campaigns
-- Expected result: 22
-- Run with: sqlite3 comm_log.db < target_base.sql or .read     target_base.sql in sqlite3 shell


-- Recursion is used instead of a self-join because retry chains can go deeper
-- than two levels (9003 -> 9002 -> 9001). A fixed number of self-joins would
-- require us to know the maximum depth in advance and could miss deeper
-- descendants such as 9003. Eligibility is deliberately not filtered here
-- because family structure is a property of the campaigns themselves.


WITH RECURSIVE campaign_tree AS (

    SELECT
        id AS campaign_id,
        id AS root_id
    FROM campaign
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.id AS campaign_id,
        ct.root_id
    FROM campaign c
    JOIN campaign_tree ct
        ON c.parent_id = ct.campaign_id
),


-- A family with more than one campaign is treated as a retry chain, while
-- a family containing only its root campaign is standalone. This classification
-- counts campaigns before eligibility filtering, so a family that later shrinks
-- to one eligible campaign still remains classified as a retry family.


family_type AS (

    SELECT
        root_id,
        CASE
            WHEN COUNT(DISTINCT campaign_id) > 1
            THEN 'retry_family'
            ELSE 'standalone'
        END AS family_type
    FROM campaign_tree
    GROUP BY root_id
),


-- Retry families count distinct customers because repeated rows represent
-- re-attempts of the same communication. Standalone campaigns count every row
-- because a repeat customer is a genuine re-target: for example, C20 was sent
-- twice ten days apart and both sends were delivered.


family_counts AS (

    SELECT
        ft.root_id,
        CASE
            WHEN ft.family_type = 'retry_family'
            THEN COUNT(DISTINCT cl.customer_id)
            ELSE COUNT(cl.customer_id)
        END AS target_base

    FROM family_type ft
    JOIN campaign_tree ct
        ON ct.root_id = ft.root_id
    JOIN campaign c
        ON c.id = ct.campaign_id
    JOIN communication_log cl
        ON cl.communication_id = c.id

    -- These are scope filters for merchant, communication type, and October
    -- 2026. They do not change the result on this extract, but are required
    -- for correctness against the full table.

    WHERE cl.merchant_id = 501
      AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01'
      AND cl.sent_time < '2026-11-01'

    -- This is the campaign eligibility gate. Campaign 9004 completed
    -- processing but its approval never cleared, so its four delivered
    -- communication sends do not contribute to target_base.

      AND c.creation_status IN (
          'approved',
          'aborted',
          'resumed',
          'stopped'
      )
      AND c.processing_status = 'processed'

    GROUP BY ft.root_id, ft.family_type
)


-- The per-family subtotals are summed to produce the reported target_base.
-- For this extract, the final result is 22.

SELECT SUM(target_base) AS final_target_base
FROM family_counts;