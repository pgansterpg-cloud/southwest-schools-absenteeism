# Chronic Absenteeism in the Southwest (2022–23)

How does chronic absenteeism in Nevada compare to Arizona, Utah, and New Mexico, and where within Nevada is it concentrated?

[**View the interactive Tableau dashboards**](https://public.tableau.com/app/profile/preston.gunter/viz/SouthwestSchoolsChronicAbsenteeism2022-23/AbsenteeismDashboard): **Absenteeism Dashboard** (state, locale, and school map) and **District Deep Dive** (district rankings and Clark County schools vs. the district rate).

![Dashboard preview](dashboard.png)

---

## Headline finding

**Clark County School District's chronic absenteeism rate (28.9%) is about 10 points higher than the rest of Nevada's (18.6%).** Because Clark enrolls roughly 64% of Nevada's students, it drives the statewide rate. Clark's ~89,000 chronically absent students is close to the total for all of New Mexico (~90,000).

Clark is not Nevada's highest district, though: among the 12 Nevada districts with 1,000+ students, it ranks **4th**, behind Lander (34.6%), Humboldt (31.2%), and White Pine (30.6%). Its size, not its rate alone, is what makes it the center of Nevada's problem.

## Why this question

I'm a special education co-teacher in the Clark County School District. I am very interested in educational data and how we can use that data to help the students I work with. I wanted to find datasets that answered questions I have on a macro level about education so I started with chronically absent students and how Nevada compares to other surrounding states.  

## The question

> How did chronic absenteeism rates in Nevada compare to Arizona, Utah, and New Mexico in the most recent available school year?

Follow-up questions:

- Does absenteeism differ by school level (elementary, middle, high)?  
- Does it differ by how urban or rural a school is?  
- Within Nevada, how does Clark County compare to the rest of the state?
- Which districts in each state have the highest rates?
- Within Clark County, which schools are furthest above the district rate?

## Data

|  |  |
| :---- | :---- |
| **Source** | [Urban Institute Education Data Portal](https://educationdata.urban.org/data-explorer), school-level data. School characteristics, enrollment, locale, and location come from the NCES **Common Core of Data (CCD)**. Chronically absent students come from the U.S. Department of Education's **Civil Rights Data Collection (CRDC)**. |
| **Year** | 2022 (the 2022–23 school year) |
| **States** | Arizona, Nevada, New Mexico, Utah |
| **Unit** | One row per school |
| **Key fields** | Enrollment, chronically absent students, school level and type, charter, virtual, urban-centric locale, district, latitude/longitude |
| **District file** | A second CCD download with one row per district (2022): district ID, name, state, agency type, enrollment, number of schools, locale. Joined to schools on `leaid`. |

**Definitions**

- **Chronically absent:** a student who missed 15 or more school days during the year, for any reason (excused, unexcused, or suspension).  
- **Enrollment:** a single-day count taken in the fall.  
- **Absenteeism rate:** `SUM(chronically absent) × 100 / SUM(enrollment)`. Students are summed before dividing, so a 2,000-student school counts more than a 20-student school. Averaging each school's rate would give small schools too much weight.

### Locale categories

Locale comes from NCES's urban-centric locale codes, which are based on Census Bureau urban area definitions. Each category is set by where the school is located and by that area's population or the school's distance from it.

| Locale | Definition |
| :---- | :---- |
| City, large / midsize / small | Inside a principal city of an urbanized area; city population 250,000+ / 100,000–249,999 / under 100,000 |
| Suburb, large / midsize / small | Inside an urbanized area but outside the principal city; urbanized area population 250,000+ / 100,000–249,999 / under 100,000 |
| Town, fringe / distant / remote | Inside a smaller urban area (urban cluster); within 10 miles / 10–35 miles / more than 35 miles from an urbanized area |
| Rural, fringe | Outside urban areas; within 5 miles of an urbanized area or within 2.5 miles of an urban cluster |
| Rural, distant | 5–25 miles from an urbanized area, or 2.5–10 miles from an urban cluster |
| Rural, remote | More than 25 miles from an urbanized area and more than 10 miles from an urban cluster |

Source: [NCES Locale Definitions](https://nces.ed.gov/programs/edge/docs/locale_definitions.pdf)

## Tools and pipeline

```
Urban Institute CSVs ──► PostgreSQL (Neon) ──► SQL cleaning + analysis ──► CSV exports ──► Tableau Public
                          schools_raw           schools_clean               schools_analysis.csv
                          districts_raw         districts_clean             district_summary.csv
                                                schools_analysis (view)     school_vs_district.csv
                                                district_summary (view)
                                                school_vs_district (view)
```

- **PostgreSQL on Neon**, managed with **pgAdmin**  
- **SQL** for cleaning, validation, and analysis (`sql/analysis.sql`)  
- **Tableau Public** for the dashboard

Database tables:

1. `schools_raw`: the original CSV, imported with every column as TEXT so nothing was lost or misread on import.  
2. `schools_clean`: typed and renamed columns, with inactive, closed, and future schools removed (5,169 schools). The primary key is `ncessch`, the NCES school ID.  
3. `schools_analysis` (view): the final analysis set of 4,193 schools.
4. `districts_raw`: the district CSV, imported as TEXT (1,055 districts).
5. `districts_clean`: typed columns, with one out-of-state row removed (1,054 districts; see cleaning decisions). The primary key is `leaid`.
6. `district_summary` (view): one row per district with analysis schools (838), with its agency type, school count, enrollment, and rate. Feeds the district ranking chart.
7. `school_vs_district` (view): every analysis school (4,193) with its own rate, its district's rate, and the gap between them. Feeds the Clark County chart.

The database connection string is stored in an environment variable (`DATABASE_URL`) and is not committed to this repo.

## Cleaning decisions

Going from 5,169 operating schools to 4,193 analysis schools:

| Removed | Schools | Why |
| :---- | :---- | :---- |
| Vocational schools | 289 | Not regular schools; students often attend part-time |
| Alternative schools | 278 | Students move in and out all year (see below) |
| Special education schools | 119 | Same enrollment problem as alternative schools |
| Regular schools with blank data | 274 | No enrollment or absenteeism reported; many are virtual |
| Enrollment of 0 | 4 | Can't calculate a rate |
| More absent than enrolled | 12 | Impossible values |
| **Total removed** | **976** | **5,169 → 4,193** |

**Why drop alternative and special education schools?** Enrollment is a one-day fall snapshot, but chronic absenteeism counts every student who attended at any point during the year. At schools where students constantly come and go, the absent count can exceed the fall enrollment. Before filtering, **109 schools reported more chronically absent students than enrolled students**. For example, Variety ES, a CCSD special education school, reports 19 students, which is far fewer than actually attend during the year.

**Sensitivity check:** Restricting the data to regular schools changed each state's rate by less than 0.5 percentage points, so this decision doesn't drive the results.

**District file checks:** Every `leaid` was unique and 7 characters long, and the whole file was one year (2022). One agency (Ombudsman Educational Services, `leaid` 0400811) listed an Illinois address, but its ID starts with 04, so it is an Arizona charter agency. It had 0 schools and no enrollment, so it was left out of `districts_clean`. A `LEFT JOIN` confirmed that **every one of the 4,193 analysis schools matches a district**.

## Key findings

### 1. By state

| State | Rate | Chronically absent students | Schools |
| :---- | :---- | :---- | :---- |
| New Mexico | **29.7%** | 90,395 | 801 |
| Arizona | 26.3% | 279,468 | 1,747 |
| Nevada | 25.2% | 120,936 | 682 |
| Utah | **14.0%** | 93,077 | 963 |

Nevada ranks in the middle of the four. Utah is the clear outlier, at about half the rate of the other three states.

**Rates vs. counts:** New Mexico has the highest *rate*, but Arizona has three times as many chronically absent students. The rate shows where the problem is most severe, and the count shows where an intervention would reach the most students.

### 2. By school level

High schools (25.0%) > middle schools (24.0%) > elementary schools (22.8%).

**Utah reverses this pattern:** its high schools (12.0%) have *lower* absenteeism than its elementary schools (16.2%).

### 3. By locale

The rate ranges from **31.8% in "Rural, remote"** schools down to **16.1% in "Suburb, small"** schools. Remote rural areas and remote towns (29.2%) have the highest rates.

### 4. Within Nevada

| District | Rate |
| :---- | :---- |
| Clark County School District | **28.9%** |
| Washoe County School District | 19.2% |
| State-sponsored charter schools | 14.3% |
| **Rest of Nevada (everything except Clark)** | **18.6%** |

### 5. Highest-absenteeism districts by state

Districts with 1,000+ students, ranked within their state with `RANK() OVER (PARTITION BY state ...)`:

| State | #1 | #2 | #3 |
| :---- | :---- | :---- | :---- |
| Arizona | Window Rock Unified (84.3%) | Chinle Unified (70.2%) | Ganado Unified (67.6%) |
| New Mexico | Socorro Consolidated (55.7%) | Española Public Schools (49.8%) | Moriarty-Edgewood (49.0%) |
| Nevada | Lander County (34.6%) | Humboldt County (31.2%) | White Pine County (30.6%) |
| Utah | Entheos Academy (41.1%) | Ogden Preparatory Academy (39.0%) | Freedom Preparatory Academy (28.1%) |

Five of Arizona's top 10 districts (Window Rock, Chinle, Ganado, Kayenta, and Piñon) are on the Navajo Nation, and Whiteriver is on the Fort Apache Reservation. That fits the locale finding: remote rural schools have the highest rates.

### 6. Clark County schools vs. the district rate

Of Clark's 351 analysis schools, **191 are above** the district rate (28.9%) and **160 are at or below** it. Among schools with 200+ students, the furthest above are NV Learning Academy J-SHS (75.8%, **+46.9 points**), Manch J E ES (+46.2), and Thomas Ruby S ES (+43.4). Half of the top 10 are large high schools with 2,000+ students each.

### 7. "Charter school" and "charter agency" are not the same

The school-level charter flag counts **731** charter schools, but only **669** belong to a charter agency. The other **62** are charters authorized by a regular district (Albuquerque 29, Clark 11, Washoe 10, and a few others), so they report under that district's ID. Comparing charter vs. non-charter schools should use the school-level flag.

## SQL techniques used

- Raw-then-clean imports (all-TEXT staging tables, `NULLIF` + casts, primary keys)
- Data checks: uniqueness (`COUNT(*)` vs. `COUNT(DISTINCT)`), ID length, blanks and zeros with `COUNT(*) FILTER (WHERE ...)`
- `INNER JOIN` and `LEFT JOIN` in both directions to find unmatched rows
- `CASE` for absenteeism tiers, school size buckets, and above/below-average labels
- Subqueries and stacked CTEs (`WITH ... AS`)
- Window functions: `RANK() OVER (PARTITION BY ... ORDER BY ...)`
- `GROUP BY` with `HAVING`
- Views to feed Tableau

## Limitations

- **Fall snapshot.** Enrollment is counted on one day in the fall, while absenteeism covers the whole year. Schools with high student turnover can look worse (or impossible) on this measure. This is why alternative and special education schools were excluded.  
- **Correlation, not causation.** These results show *where* absenteeism is high, not *why*. Clark County differs from the rest of Nevada in poverty, size, and student population, and this analysis doesn't separate those factors.  
- **Locale is based on school address.** It describes where the school is, not where students live, and it isn't a measure of income.  
- **One school year.** 2022–23 was still close to the COVID-19 disruptions, so these rates may be higher than in a typical year. One year can't show trends.  
- **Title I status was blank** for every 2022 row, so poverty couldn't be included in this version.  
- **Excluded schools.** The findings apply to regular schools only.
- **District rankings use a 1,000-student cutoff.** Small districts and one-school charter agencies can have extreme rates from just a few students, so they were left out of the rankings. For one-school agencies, the school *is* the district, so the school-vs-district gap is always 0.
- **Location is not a cause.** The high rates in Navajo Nation and other remote districts likely reflect distance, weather, transportation, and access to services, but this data can't show that.

## Next steps (v2)

- **Automate the data pull with Python** using the Urban Institute Education Data API, instead of downloading from the Data Explorer by hand.  
- **Join Title I status from another year** on `ncessch` to test whether poverty explains the Clark County gap.  
- **Add a national benchmark** for context.  
- Explore **absenteeism vs. state test scores**.

## Repo contents

| File | Description |
| :---- | :---- |
| `sql/analysis.sql` | All SQL in order: building `schools_clean`, data checks, the `schools_analysis` view, each analysis query with its results, then the district import, joins, CASE, CTEs, rankings, and the two Tableau views |
| `data/EducationDataPortal_10.05.2026_Schools.csv` | The raw download from the Urban Institute Data Explorer (imported into `schools_raw`) |
| `data/EducationDataPortal_10.05.2026_datadictionary.csv` | Data dictionary from the download: each variable's label, source, and year |
| `data/schools_analysis.csv` | The final 4,193-school dataset used in Tableau |
| `data/EducationDataPortal_10.14.2026_School Districts.csv` | The raw district download (imported into `districts_raw`) |
| `data/district_summary.csv` | Export of the `district_summary` view (838 districts), used in Tableau |
| `data/school_vs_district.csv` | Export of the `school_vs_district` view (4,193 schools), used in Tableau |
| `dashboard.png` | Screenshot of the Tableau dashboard |
| `README.md` | This file |

## About me

Preston Gunter, special education co-teacher in the Clark County School District transitioning into data analytics. Computer Information Technology degree, BYU-Idaho.
