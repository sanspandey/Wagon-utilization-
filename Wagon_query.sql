use railway_db;

# trip per wagon
SELECT 
	wagon_id,
    COUNT(trip_id) AS total_trips
FROM trip_df_modified
GROUP BY wagon_id
ORDER BY total_trips DESC;

# ldle time using window function 
WITH wagon_gaps  AS (
	SELECT 
		wagon_id,
        departure_time,
        LAG(arrival_time) OVER (
			PARTITION BY  wagon_id
            ORDER BY departure_time
        ) AS previos_arrival
        FROM trip_df_modified
)
SELECT 
	wagon_id,
    ROUND(
		AVG(TIMESTAMPDIFF(HOUR, previos_arrival, departure_time)), 2
    )AS avg_idle_hrs,
    ROUND(
		MAX(TIMESTAMPDIFF(HOUR, previos_arrival, departure_time)), 2
    )AS max_idle_hrs
FROM wagon_gaps
WHERE previos_arrival IS NOT NULL
GROUP BY wagon_id
ORDER BY  avg_idle_hrs DESC;

#utilization classification
WITH trip_stats AS (
	SELECT 
		wagon_id,
        COUNT(*) AS total_trips
	FROM trip_df_modified
    GROUP BY wagon_id
),
avg_stats AS (
	SELECT AVG(total_trips) AS avg_trips FROM trip_stats
)
SELECT 
	t.wagon_id,
    t.total_trips,
    CASE
		WHEN t.total_trips >= a.avg_trips * 1.2 THEN 'high utilization'
        WHEN t.total_trips <= a.avg_trips * 0.8 THEN 'low utilization'
        ELSE 'medium utilization'
	END AS  utilization_catgory
FROM trip_stats t
CROSS JOIN avg_stats a;

#detect idle yet active wagons
SELECT 
	w.wagon_id,
    w.status,
    COALESCE(t.total_trips,0) AS total_trips
FROM wagon_df w
LEFT JOIN (
	SELECT wagon_id, COUNT(*) AS total_trips
    FROM trip_df_modified
    GROUP BY wagon_id
) t ON w.wagon_id = t.wagon_id
WHERE w.status = 'Active'
ORDER BY total_trips ASC;

# rout wise delay analysis
SELECT 
	r.route_id,
    r.source,
    r.destination,
    COUNT(t.trip_id) AS total_trips,
    SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) delay_trips,
    ROUND(
		100.0 * SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) / COUNT(t.trip_id),
        2
    ) AS delay_percentage,
    ROUND(AVG(t.delay_hr), 2) AS avg_delay_hr,
    MAX(T.delay_hr) AS max_delay_hr
FROM trip_df_modified t
JOIN routS_csv r ON t.route_id = r.route_id
GROUP BY r.route_id, r.source, r.destination
ORDER BY  delay_percentage DESC;

# identify Bottelneck Routs
SELECT * 
FROM (
	SELECT 
		r.route_id,
		r.source,
		r.destination,
		COUNT(*) AS total_trips,
		ROUND(
			100.0 * SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) / COUNT(*),
			2
		) AS delay_pct,
		ROUND(AVG(t.delay_hr),2) AS avg_delay
	FROM trip_df_modified t
	JOIN routs_csv r ON t.route_id = r.route_id
    GROUP BY r.route_id, r.source, r.destination
) x
WHERE delay_pct > 40 AND avg_delay > 6
ORDER BY  delay_pct DESC;

# zone wise delay 
SELECT 
	r.zone,
    COUNT(t.trip_id) AS total_trips,
    SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) AS delay_trips,
    ROUND(
		100.0 * SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    )AS delay_percentage,
    ROUND(AVG(t.delay_hr),2) AS avg_delay_hr
FROM trip_df_modified t
JOIN routs_csv r ON t.route_id = r.route_id
GROUP BY r.zone
ORDER BY delay_percentage DESC;

# distance vs delay correlation 
SELECT 
	r.route_id,
    r.distance_km,
    ROUND(AVG(t.delay_hr), 2) AS avg_delay
FROM trip_df_modified t
JOIN routs_csv r ON t.route_id = r.route_id
GROUP BY r.route_id, r.distance_km
ORDER BY  avg_delay DESC;

# cargo load effficieancy & overloading  analysis 
# total cargo load per trips 
SELECT 
	trip_id,
    SUM(weight_tons) AS total_load_tons
FROM cargo_df
GROUP BY trip_id;

# join cargo + trip + wagon
SELECT 
	t.trip_id,
    t.wagon_id,
    w.capacity_tons,
    SUM(c.weight_tons) AS total_load_tons,
    ROUND(
		(SUM(c.weight_tons) / w.capacity_tons) * 100, 2
	) AS utilization_pct
FROM trip_df_modified t
JOIN cargo_df c ON t.trip_id = c.trip_id
JOIN wagon_df w ON t.wagon_id = w.wagon_id
GROUP BY t.trip_id, t.wagon_id, w.capacity_tons;

# classify load efficiency
SELECT
	x.trip_id,
    x.wagon_id,
    x.capacity_tons,
    x.total_load_tons,
    x.utilization_pct,
    CASE 
		WHEN x.utilization_pct > 100 THEN 'Overloaded'
        WHEN x.utilization_pct < 70 THEN 'underutilization'
        ELSE 'optimal'
	END AS load_status
FROM (
	SELECT
		t.trip_id,
        t.wagon_id,
        w.capacity_tons,
        SUM(c.weight_tons) AS total_load_tons,
        ROUND(
			(SUM(c.weight_tons)/ w.capacity_tons) * 100, 2
        ) AS utilization_pct
        
	FROM trip_df_modified t
    JOIN cargo_df c ON t.trip_id = c.trip_id
    JOIN wagon_df w ON 	t.wagon_id = w.wagon_id
	GROUP BY t.trip_id, t.wagon_id, w.capacity_tons
)x;

#Overall load Efficiancy 
SELECT
	load_status,
    COUNT(*) AS trip_count
FROM (
	SELECT 
		t.trip_id,
        CASE
			WHEN(SUM(c.weight_tons)/ w.capacity_tons) *100 > 100 THEN "OVERLOAD"
            WHEN(SUM(c.weight_tons)/ w.capacity_tons) * 100 < 70 THEN "utilization"
            ELSE "OPTIMAL"
		END AS load_status
	FROM trip_df_modified t
    JOIN cargo_df c ON t.trip_id = c.trip_id
    JOIN wagon_df w ON t.wagon_id = w.wagon_id
    GROUP BY t.trip_id, w.capacity_tons
) y
GROUP BY load_status;

# wagonn level load risk
SELECT 
	wagon_id,
    COUNT(*) AS total_trip,
    SUM(CASE WHEN load_status ='OVERLOAD' THEN 1 ELSE 0 END) AS overloaded_trips
FROM (
	SELECT
		t.trip_id,
        w.wagon_id,
        CASE
			WHEN (SUM(c.weight_tons)/ w.capacity_tons) * 100 < 100 THEN 'overload'
            ELSE 'normal'
		END AS load_status
	FROM trip_df_modified t
    JOIN cargo_df c ON t.trip_id = c.trip_id
    JOIN wagon_df w ON t.wagon_id = w.wagon_id
    GROUP BY t.trip_id, t.wagon_id, w.capacity_tons
) z
GROUP BY wagon_id
ORDER BY overloaded_trips DESC;

#Rout wise load efficiency 
SELECT 
	r.route_id,
    COUNT(*) AS total_trip,
    SUM(CASE WHEN utilization_pct < 70 THEN 1 ELSE 0 END)  AS underutilized_trips
FROM (
	SELECT 
		t.trip_id,
        t.route_id,
        (SUM(c.weight_tons) / w.capacity_tons) *100 AS utilization_pct
	FROM trip_df_modified t
    JOIN cargo_df c ON t.trip_id = c.trip_id
    JOIN wagon_df w ON t.wagon_id = w.wagon_id
    GROUP BY t.trip_id, t.route_id, w.capacity_tons
) x
JOIN routs_csv r ON x.routE_id = r.routE_id
GROUP BY r.route_id
ORDER BY underutilized_trips DESC;

# MAINTANANCE & DOWNTIME ANALYSIS
# wagon wise maintanance frequency
SELECT 
	wagon_id,
    COUNT(maintenance_id) AS maintenance_count
FROM maintanence_csv
GROUP BY wagon_id
ORDER BY maintenance_count DESC;

# wagon wisw downtimw
SELECT
	wagon_id,
    SUM(downtime_days) AS total_downtime_days
FROM maintanence_csv
GROUP BY wagon_id
ORDER BY total_downtime_days DESC;

# maintanenc severity analysis
SELECT 
	wagon_id,
	ROUND(AVG(downtime_days),2) AS avg_downtime_per_event,
    MAX(downtime_days) AS max_single_downtime
FROM maintanence_csv
GROUP BY wagon_id
ORDER BY avg_downtime_per_event DESC;

# preactive vs corrective 
SELECT 
	maintenance_type,
    COUNT(*) AS maintenance_type,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(),2) AS percentage
FROM maintanence_csv
GROUP BY maintenance_type;

# maintenance risk classification
WITH downtime_stats AS (
	SELECT 
		wagon_id,
        SUM(downtime_days) AS total_downtime
	FROM maintanence_csv
    GROUP BY wagon_id
),
avg_val AS (
	SELECT AVG(total_downtime) AS avg_downtime FROM downtime_stats
)
SELECT 
	d.wagon_id,
    d.total_downtime,
    CASE
		WHEN d.total_downtime > a.avg_downtime * 1.5 THEN 'high risk'
        WHEN d.total_downtime < a.avg_downtime * 0.7 THEN 'low risk'
        ELSE 'medium risk'
	END AS maintanence_risk
FROM downtime_stats d
CROSS JOIN avg_val  a
ORDER BY d.total_downtime DESC;

# maintanance impact on delays 
SELECT 
	m.wagon_id,
    SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) AS delayed_trips,
    COUNT(t.trip_id) AS total_trips
FROM maintanence_csv m
JOIN trip_df_modified t
ON m.wagon_id = t.wagon_id
GROUP BY m.wagon_id
ORDER BY delayed_trips DESC;

# Build Unifide Analytical View 
# Wagon performance summary table
WITH trips_stats AS (
	SELECT 
		wagon_id,
        COUNT(*) AS total_trips,
        AVG(delay_hr) AS avg_delay
	FROM trip_df_modified
    GROUP BY wagon_id
),
idle_stats AS (
	SELECT 
		wagon_id,
        AVG(TIMESTAMPDIFF(HOUR, previous_arrival, departure_time)) AS avg_idle
	FROM (
		SELECT
			wagon_id,
            departure_time,
            LAG(arrival_time) OVER (PARTITION BY wagon_id ORDER BY departure_time) AS previous_arrival
		FROM trip_df_modified
    ) x
    WHERE previous_arrival IS NOT NULL
    GROUP BY wagon_id
), 
maintanence_stats AS (
	SELECT 
		wagon_id,
        COUNT(*) AS maintenance_count,
        SUM(downtime_days) AS total_downtime
	FROM maintanence_csv
    GROUP BY wagon_id
)
SELECT 
	w.wagon_id,
    COALESCE(t.total_trips,0) AS total_trips,
    ROUND(COALESCE(t.avg_delay,0),2) AS avg_delay_hr,
    ROUND(COALESCE(i.avg_idle,0),2) AS avg_idle_hr,
    COALESCE(m.maintenance_count,0) AS maintenance_event,
    COALESCE(m.total_downtime,0) AS downtime_days
    
FROM wagon_df w
LEFT JOIN trips_stats t ON w.wagon_id = t.wagon_id
LEFT JOIN idle_stats i ON w.wagon_id = i.wagon_id
LEFT JOIN maintanence_stats m ON w.wagon_id = m.wagon_id
ORDER BY avg_delay_hr DESC;

# maintanence vs delay relation 
SELECT 
	CASE 
		WHEN total_downtime > 20 THEN 'high downtime'
        WHEN total_downtime BETWEEN 10 AND 20 THEN 'medium downtime'
        ELSE  'low downtime'
	END AS  downtime_category,
    ROUND(AVG(avg_delay_hr),2) AS avg_delay
FROM (
	SELECT 
		m.wagon_id,
        SUM(m.downtime_days) AS total_downtime,
        AVG(t.delay_hr) AS avg_delay_hr
	FROM maintanence_csv m
    JOIN trip_df_modified t ON m.wagon_id = t.wagon_id
    GROUP BY m.wagon_id
) x
GROUP BY  downtime_category;

# Load effi vs delay impact 
SELECT 
	load_stats,
    ROUND(AVG(delay_hr),2) AS avg_delay_hr
FROM (
	SELECT 
		t.trip_id,
        t.delay_hr,
        CASE 
			WHEN (SUM(c.weight_tons) / w.capacity_tons) * 100 > 100 THEN 'overloaded'
            WHEN (SUM(c.weight_tons) / w.capacity_tons) * 100 < 70  THEN 'underutilized'
            ELSE 'optimal'
		END AS load_stats
	FROM trip_dF_modified t 
    JOIN cargo_df c ON  t.trip_id = c.trip_id
    JOIN wagon_df w ON t.wagon_id = w.wagon_id
    GROUP BY  t.trip_id, t.delay_hr, w.capacity_tons
) y
GROUP BY load_stats;

# Identify high risk wagons

SELECT *
FROM (
    SELECT
        w.wagon_id,
        COUNT(t.trip_id) AS total_trips,
        SUM(CASE WHEN t.delay_hrs > 0 THEN 1 ELSE 0 END) AS delay_trips,
        SUM(m.downtime_days) AS downtime_days,
        ROUND(AVG(t.delay_hrs), 2) AS avg_delay
    FROM wagon_df w
    LEFT JOIN trip_df_modified t
        ON w.wagon_id = t.wagon_id
    LEFT JOIN maintenance_csv m
        ON w.wagon_id = m.wagon_id
    GROUP BY w.wagon_id
) x
WHERE delay_trips > 10
  AND downtime_days > 15
ORDER BY downtime_days DESC;


# SECTION 1 : FINAL SQL REPORT 
SELECT COUNT(*) FROM wagon_df;
SELECT COUNT(*) FROM cargo_df;
SELECT COUNT(*) FROM routs_csv;
SELECT COUNT(*) FROM trip_df_modified;
SELECT COUNT(*) FROM maintanence_csv;

SELECT * FROM trip_dF_modified
WHERE wagoN_id IS NULL OR route_id IS NULL;

# SECTION 2 : WAGON UTILIZATION & IDLE TIME 
SELECT 
	wagon_id,
    COUNT(trip_id) AS total_trips
FROM trip_df_modified
GROUP BY wagon_id
ORDER BY total_trips DESC;

## avg & amx idle time
WITH gaps AS (
	SELECT 
		wagon_id,
        departure_time,
        LAG(arrival_time) OVER (
			PARTITION BY wagon_id
            ORDER BY departure_time
        ) AS prev_arrival
	FROM trip_df_modified
)
SELECT 
	wagon_id,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, prev_arrival, departure_time)),2) AS avg_idle_hr,
    ROUND(MAX(TIMESTAMPDIFF(HOUR, prev_arrival, departure_time)),2) AS max_idle_hr
FROM gaps
WHERE prev_arrival IS NOT NULL
GROUP BY wagon_id;

# Rout delay Analysis

SELECT 
	r.route_id,
    COUNT(t.trip_id) AS total_trips,
    SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) AS delayed_trips,
    ROUND(
		100.0 * SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS delay_pct,
	ROUND(AVG(t.delay_hr),2) AS avg_delay
FROM trip_Df_modified t
JOIN routs_csv r 
	ON t.route_id = r.route_id
GROUP BY r.route_id
ORDER BY delay_pct  DESC;


# Cargo load efficiency 
SELECT 
	load_status,
    COUNT(*) AS trip_count
FROM (
	SELECT 
		t.trip_id,
        CASE
			WHEN (SUM(c.weight_tons) / w.capacity_tons)*100 > 100 THEN 'overloaded'
            WHEN (SUM(c.weight_tons) / w.capacity_tons)*100 < 70 THEN 'underutilized'
            ELSE 'optimal'
		END AS load_status
	FROM trip_df_modified t
    JOIN cargo_df c ON c.trip_id = t.trip_id
	JOIN wagon_df w ON t.wagon_id = w.wagon_id
    GROUP BY t.trip_id, w.capacity_tons
) x
GROUP BY load_status;

# maintanence downtime
SELECT
	wagon_id,
    COUNT(*) AS maintenence_id,
    SUM(downtime_days) AS downtime_days
FROM maintanence_csv 
GROUP BY wagon_id
ORDER BY downtime_days DESC;

# iNTEGRAL ANALYSIS 
SELECT *
FROM (
	SELECT 
		w.wagon_id,
        COUNT(t.trip_id) AS total_trips,
        SUM(CASE WHEN t.delay_hr > 0 THEN 1 ELSE 0 END) AS delayed_trips,
        SUM(m.downtime_days) AS downtime_days,
        ROUND(AVG(t.delay_hr),2) AS avg_delay
	FROM wagon_df w
    LEFT JOIN trip_df_modified t 
		ON w.wagon_id = t.wagon_id
	LEFT JOIN maintanence_csv m
		ON w.wagon_id = m.wagon_id
	GROUP BY w.wagon_id
) x
WHERE delayed_trips > 0 
AND downtime_days > 15
ORDER BY downtime_days DESC;

SELECT @@hostname;

SELECT
    CASE
        WHEN delay_pct > 40 OR high_risk_pct > 15 THEN 'High Risk'
        WHEN delay_pct > 20 OR high_risk_pct > 5 THEN 'Medium Risk'
        ELSE 'Healthy'
    END AS operational_health
FROM (
    SELECT
        ROUND(
            100.0 * SUM(CASE WHEN delay_hr > 0 THEN 1 ELSE 0 END) / COUNT(*),
            2
        ) AS delay_pct
    FROM trip_df_modified
) d,
(
    SELECT
        ROUND(
            100.0 * SUM(CASE WHEN maintanence_risk = 'High Risk' THEN 1 ELSE 0 END)
            / COUNT(*),
            2
        ) AS high_risk_pct
    FROM risk_wagon
) r;

