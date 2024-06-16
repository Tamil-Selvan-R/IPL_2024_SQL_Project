--Top 10 batsmen based on past 3 years batting average. (min 60 balls faced in each season)
WITH cte AS (
    SELECT 
        a.year,
        b.teamInnings,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        AVG(b.runs) AS avg_runs,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a 
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
        ON a.match_id = b.match_id
    GROUP BY 
        a.year, 
        b.batsmanName,
        b.teamInnings
),
cte_filtered AS (
    SELECT *
    FROM cte
    WHERE sum_balls >= 60 AND year IN (2021, 2022, 2023)
),
cte_per_year AS (
    SELECT 
        batsmanName, 
        year,
        COUNT(*) OVER (PARTITION BY batsmanName) AS year_count
    FROM cte_filtered
    WHERE year IN (2021, 2022, 2023)
),
cte_all_years AS (
    SELECT DISTINCT batsmanName
    FROM cte_per_year
    WHERE year_count = 3
),
cte_runs AS (
    SELECT 
        a.batsmanName,
        SUM(a.total_runs) AS total_runs
    FROM cte_filtered a
    JOIN cte_all_years b ON a.batsmanName = b.batsmanName
    GROUP BY a.batsmanName
),
cte_outs AS (
    SELECT 
        batsmanName,
        COUNT(*) AS count_out
    FROM [project].[dbo].[fact_bating_summary]
    WHERE out_not_out = 'out'
    GROUP BY batsmanName
),
cte_aggregate AS (
    SELECT 
        a.batsmanName,
        a.total_runs,
        COALESCE(b.count_out, 0) AS count_out
    FROM cte_runs a
    LEFT JOIN cte_outs b ON a.batsmanName = b.batsmanName
),
cte_avg AS (
    SELECT 
        batsmanName,
        CASE 
            WHEN count_out = 0 THEN NULL
            ELSE CAST(total_runs AS FLOAT) / count_out
        END AS avg
    FROM cte_aggregate
)
SELECT 
    TOP 10 batsmanName, 
    avg
FROM 
    cte_avg
ORDER BY 
    avg DESC;

-----------------------------------------------------------------------------------------
WITH batting_summary AS (
    SELECT
        a.year,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    GROUP BY 
        a.year, 
        b.batsmanName
),
filtered_batsmen AS (
    SELECT 
        batsmanName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023
    FROM 
        batting_summary
    GROUP BY 
        batsmanName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
batsman_strike_rates AS (
    SELECT
        batsmanName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 100.0 / 
        (SUM(balls_2021) + SUM(balls_2022) + SUM(balls_2023)) AS strike_rate
    FROM
        filtered_batsmen
    GROUP BY
        batsmanName
)

SELECT TOP 10
    batsmanName,
    strike_rate
FROM
    batsman_strike_rates
ORDER BY
    strike_rate DESC;

	---------------------------------------------

	WITH batting_summary AS (
    SELECT
        a.year,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        SUM(b.runs) AS total_runs,
        SUM(CASE WHEN b.out_not_out = 'out' THEN 1 ELSE 0 END) AS total_outs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    GROUP BY 
        a.year, 
        b.batsmanName
),
filtered_batsmen AS (
    SELECT 
        batsmanName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023,
        SUM(CASE WHEN year = 2021 THEN total_outs ELSE 0 END) AS outs_2021,
        SUM(CASE WHEN year = 2022 THEN total_outs ELSE 0 END) AS outs_2022,
        SUM(CASE WHEN year = 2023 THEN total_outs ELSE 0 END) AS outs_2023
    FROM 
        batting_summary
    GROUP BY 
        batsmanName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
batsman_averages AS (
    SELECT
        batsmanName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 1.0 / 
        NULLIF(SUM(outs_2021) + SUM(outs_2022) + SUM(outs_2023), 0) AS batting_average
    FROM
        filtered_batsmen
    GROUP BY
        batsmanName
)

SELECT TOP 10
    batsmanName,
    batting_average
FROM
    batsman_averages
ORDER BY
    batting_average DESC;

	WITH cte AS (
    SELECT 
        a.year,
        b.teamInnings,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        AVG(b.runs) AS avg_runs,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a 
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
        ON a.match_id = b.match_id
    GROUP BY 
        a.year, 
        b.batsmanName,
        b.teamInnings
),
cte1 AS (
    SELECT *
    FROM cte
    WHERE sum_balls >= 60 AND year = 2023
),
cte2 AS (
    SELECT *
    FROM cte
    WHERE sum_balls >= 60 AND year = 2022
),
cte3 AS (
    SELECT *
    FROM cte
    WHERE sum_balls >= 60 AND year = 2021
),

cte4 as(SELECT * 
FROM (
    SELECT  * 
    FROM cte1 
    
) AS top_cte1

UNION ALL

SELECT * 
FROM (
    SELECT   * 
    FROM cte2 
    
) AS top_cte2

UNION ALL

SELECT * 
FROM (
    SELECT  * 
    FROM cte3 
    
) AS top_cte3),

cte5 as(select batsmanname,COUNT(out_not_out) count_out
from [project].[dbo].[fact_bating_summary]
where out_not_out = 'out'
group by batsmanName),

cte6 as(select a.batsmanName,SUM(a.total_runs) t_runs,b.count_out
from cte4 a join cte5 b on a.batsmanName=b.batsmanName
group by a.batsmanName,b.count_out)


select top 10 batsmanname,AVG
from (select batsmanname,(t_runs/count_out) avg
from cte6) a
order by avg desc;
---------------------------------------------------------------------------------------------------

---1. Top 10 batsmen based on past 3 years total runs scored



WITH batting_summary AS (
    SELECT
        b.batsmanName,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
		
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        b.batsmanName
)

SELECT TOP 10
    batsmanName,
    total_runs
FROM
    batting_summary
ORDER BY
    total_runs DESC;

------------------------------------------------------------------------------------------------------------------------------------
--2. Top 10 batsmen based on past 3 years batting average (min 60 balls faced in each season)



WITH batting_summary AS (
    SELECT
        a.year,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        SUM(b.runs) AS total_runs,
        SUM(CASE WHEN b.out_not_out = 'out' THEN 1 ELSE 0 END) AS total_outs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year, 
        b.batsmanName
),
filtered_batsmen AS (
    SELECT 
        batsmanName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023,
        SUM(CASE WHEN year = 2021 THEN total_outs ELSE 0 END) AS outs_2021,
        SUM(CASE WHEN year = 2022 THEN total_outs ELSE 0 END) AS outs_2022,
        SUM(CASE WHEN year = 2023 THEN total_outs ELSE 0 END) AS outs_2023
    FROM 
        batting_summary
    GROUP BY 
        batsmanName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
batsman_averages AS (
    SELECT
        batsmanName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 1.0 / 
        NULLIF(SUM(outs_2021) + SUM(outs_2022) + SUM(outs_2023), 0) AS batting_average
    FROM
        filtered_batsmen
    GROUP BY
        batsmanName
)

SELECT TOP 10
    batsmanName,
    batting_average
FROM
    batsman_averages
ORDER BY
    batting_average DESC;

------------------------------------------------------------------------------------------------------------------------------------
--3. Top 10 batsmen based on past 3 years strike rate (min 60 balls faced in each season)



WITH batting_summary AS (
    SELECT
        a.year,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year, 
        b.batsmanName
),
filtered_batsmen AS (
    SELECT 
        batsmanName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023
    FROM 
        batting_summary
    GROUP BY 
        batsmanName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
batsman_strike_rates AS (
    SELECT
        batsmanName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 100.0 / 
        SUM(balls_2021 + balls_2022 + balls_2023) AS strike_rate
    FROM
        filtered_batsmen
    GROUP BY
        batsmanName
)

SELECT TOP 10
    batsmanName,
    strike_rate
FROM
    batsman_strike_rates
ORDER BY
    strike_rate DESC;

------------------------------------------------------------------------------------------------------------------------------------
--4. Top 10 bowlers based on past 3 years total wickets taken


WITH bowling_summary AS (
    SELECT
        b.bowlerName,
        SUM(b.wickets) AS total_wickets
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[f_bowling] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        b.bowlerName
)

SELECT TOP 10
    bowlerName,
    total_wickets
FROM
    bowling_summary
ORDER BY
    total_wickets DESC;


------------------------------------------------------------------------------------------------------------------------------------
--5. Top 10 bowlers based on past 3 years bowling average (min 60 balls bowled in each season)




WITH bowling_summary AS (
    SELECT
        a.year,
        b.bowlerName,
        SUM(CAST(b.overs AS INT) * 6)  AS sum_balls, -- Convert overs to balls
        SUM(cast(b.runs as int))  AS total_runs,
        SUM(cast(b.wickets as int)) AS total_wickets
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[f_bowling] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year, 
        b.bowlerName
),
filtered_bowlers AS (
    SELECT 
        bowlerName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023,
        SUM(CASE WHEN year = 2021 THEN total_wickets ELSE 0 END) AS wickets_2021,
        SUM(CASE WHEN year = 2022 THEN total_wickets ELSE 0 END) AS wickets_2022,
        SUM(CASE WHEN year = 2023 THEN total_wickets ELSE 0 END) AS wickets_2023
    FROM 
        bowling_summary
    GROUP BY 
        bowlerName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
bowler_averages AS (
    SELECT
        bowlerName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 1.0 / 
        NULLIF(SUM(wickets_2021) + SUM(wickets_2022) + SUM(wickets_2023), 0) AS bowling_average
    FROM
        filtered_bowlers
    GROUP BY
        bowlerName
)

SELECT TOP 10
    bowlerName,
    bowling_average
FROM
    bowler_averages
ORDER BY
    bowling_average ASC;




------------------------------------------------------------------------------------------------------------------------------------
--Adjusted 6. Top 10 bowlers based on past 3 years economy rate (min 60 balls bowled in each season)



WITH bowling_summary AS (
    SELECT
        a.year,
        b.bowlerName,
        SUM(CAST(b.overs AS INT) * 6) AS sum_balls, -- Convert overs to balls
        SUM(cast(b.runs AS int)) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[f_bowling] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year, 
        b.bowlerName
),
filtered_bowlers AS (
    SELECT 
        bowlerName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023
    FROM 
        bowling_summary
    GROUP BY 
        bowlerName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),
bowler_economy AS (
    SELECT
        bowlerName,
        (SUM(runs_2021) + SUM(runs_2022) + SUM(runs_2023)) * 6.0 / 
        SUM(balls_2021 + balls_2022 + balls_2023) AS economy_rate
    FROM
        filtered_bowlers
    GROUP BY
        bowlerName
)

SELECT TOP 10
    bowlerName,
    economy_rate
FROM
    bowler_economy
ORDER BY
    economy_rate ASC;

------------------------------------------------------------------------------------------------------------------------------------
--7. Top 5 batsmen based on past 3 years boundary % (fours and sixes)

select * from [project].[dbo].[fact_bating_summary];

WITH batting_summary AS (
    SELECT
        a.year,
        b.batsmanName,
        SUM(b.balls) AS sum_balls,
        SUM(b.[_4s]) AS total_fours,
        SUM(b.[_6s]) AS total_sixes,
        SUM(b.runs) AS total_runs
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[fact_bating_summary] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year,
        b.batsmanName
),
cte_filtered AS (
    SELECT
        batsmanName
    FROM
        batting_summary
    WHERE
        sum_balls >= 60
    GROUP BY
        batsmanName
    HAVING
        COUNT(DISTINCT year) = 3
),
cte_boundary_runs AS (
    SELECT
        b.batsmanName,
        SUM(b.total_fours * 4) AS four_runs,
        SUM(b.total_sixes * 6) AS six_runs,
        SUM(b.total_fours * 4 + b.total_sixes * 6) AS boundary_runs,
        SUM(b.total_runs) AS total_runs
    FROM
        batting_summary b
    JOIN
        cte_filtered f ON b.batsmanName = f.batsmanName
    GROUP BY
        b.batsmanName
),
cte_boundary_percentage AS (
    SELECT
        batsmanName,
        boundary_runs,
        total_runs,
        (CAST(boundary_runs AS FLOAT) / total_runs) * 100 AS boundary_percentage
    FROM
        cte_boundary_runs
    WHERE
        total_runs > 0
)

SELECT
    top 10 batsmanName,
    boundary_percentage
FROM
    cte_boundary_percentage
ORDER BY
    boundary_percentage DESC;

	------------------------------------------------------------------------------------------------------------------------------------
--8.Top 4 teams based on past 3 years winning %

with cte as(select distinct team1 ,COUNT(match_id) over(partition by team1) c1,COUNT(match_id) over(partition by team2) c2
from dim_match_summary)

select team1, ;

WITH match_summary AS (
    SELECT 
        match_id,
        TRY_CONVERT(DATE, matchDate) AS matchDate,
        winner
    FROM 
        [project].[dbo].[dim_match_summary]
    WHERE 
        TRY_CONVERT(DATE, matchDate) IS NOT NULL
        AND YEAR(TRY_CONVERT(DATE, matchDate)) IN (2021, 2022, 2023)
),
team_wins AS (
    SELECT 
        winner AS team,
        COUNT(match_id) AS total_wins
    FROM 
        match_summary
    WHERE 
        winner IS NOT NULL
    GROUP BY 
        winner
),
wins as(SELECT 
    team,
    total_wins
FROM 
    team_wins
),



team_matches AS (
    SELECT 
        team,
        COUNT(match_id) AS total_matches
    FROM (
        SELECT 
            team1 AS team,
            match_id
        FROM 
            dim_match_summary
        UNION ALL
        SELECT 
            team2 AS team,
            match_id
        FROM 
            dim_match_summary
    ) AS team_matches_union
    GROUP BY 
        team)

select a.team,total_matches,total_wins,round((cast (total_wins as float) /total_matches) * 100,2) as win_percentage
from wins a join team_matches b on a.team = b.team
order by win_percentage desc;



------------------------------------------------------------------------------------------------------------------------------------
--9.Top 2 teams with the highest number of wins achieved by chasing targets over the past 3 years.

WITH match_summary AS (
    SELECT 
        match_id,
        TRY_CONVERT(DATE, matchDate) AS matchDate,
        winner,
		margin
    FROM 
        [project].[dbo].[dim_match_summary]
    WHERE 
        TRY_CONVERT(DATE, matchDate) IS NOT NULL
        AND YEAR(TRY_CONVERT(DATE, matchDate)) IN (2021, 2022, 2023)
),
team_wins AS (
    SELECT 
        winner AS team,
        COUNT(match_id) AS total_wins
    FROM 
        match_summary
    WHERE 
        winner IS NOT NULL and margin like '%wickets'
    GROUP BY 
        winner
)
SELECT 
    team,
    total_wins
FROM 
    team_wins;


	------------------------------------------------------------------------------------------------------------------------------------
--10.Top 5 bowlers based on past 3 years dot ball %
	

WITH bowling_summary AS (
    SELECT
        a.year,
        b.bowlerName,
        SUM(CAST(b.overs AS INT) * 6)  AS sum_balls, -- Convert overs to balls
        SUM(cast(b.runs as int))  AS total_runs,
        SUM(cast(b.wickets as int)) AS total_wickets
    FROM 
        [project].[dbo].[dim_match_summary] a
    JOIN 
        [project].[dbo].[f_bowling] b 
    ON 
        a.match_id = b.match_id
    WHERE 
        a.year IN (2021, 2022, 2023)
    GROUP BY 
        a.year, 
        b.bowlerName
),
filtered_bowlers AS (
    SELECT 
        bowlerName,
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) AS balls_2021,
        SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) AS balls_2022,
        SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) AS balls_2023,
        SUM(CASE WHEN year = 2021 THEN total_runs ELSE 0 END) AS runs_2021,
        SUM(CASE WHEN year = 2022 THEN total_runs ELSE 0 END) AS runs_2022,
        SUM(CASE WHEN year = 2023 THEN total_runs ELSE 0 END) AS runs_2023,
        SUM(CASE WHEN year = 2021 THEN total_wickets ELSE 0 END) AS wickets_2021,
        SUM(CASE WHEN year = 2022 THEN total_wickets ELSE 0 END) AS wickets_2022,
        SUM(CASE WHEN year = 2023 THEN total_wickets ELSE 0 END) AS wickets_2023
    FROM 
        bowling_summary
    GROUP BY 
        bowlerName
    HAVING 
        SUM(CASE WHEN year = 2021 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2022 THEN sum_balls ELSE 0 END) >= 60
        AND SUM(CASE WHEN year = 2023 THEN sum_balls ELSE 0 END) >= 60
),

dotball as(select bowlername,SUM(_0s) as dots
from f_bowling
group by bowlerName),

per as (select a.bowlerName,sum(balls_2021+balls_2022+balls_2023) total_balls,sum(dots) d
from filtered_bowlers a join dotball b on a.bowlerName = b.bowlerName
group by a.bowlerName)

select  top 5 bowlername,round((cast (d as float)/total_balls) * 100,2) as perce
from per
order by  perce desc