CREATE database AlexCovid;

USE alexcovid;

-- use table import wizard to create table
SELECT * FROM alexcovid.coviddeaths
ORDER BY 3, 4;
SELECT COUNT(*) FROM alexcovid.coviddeaths;

-- Records were not properly inserted. Delete records to allow for importation via load data infile query
-- Turn on and off sql safe updates to allow deletion of records from table
SET SQL_SAFE_UPDATES = 0;
DELETE FROM coviddeaths;
SET SQL_SAFE_UPDATES = 1;

-- Load data infile from local computer
LOAD DATA LOCAL INFILE 'C:\Users\ABC\Desktop\DA\Alex Covid SQL\CovidDeaths.csv'
INTO TABLE coviddeaths
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Loading Local data is disabled. Enable by doing the following
SHOW VARIABLES like 'local_infile';
SET GLOBAL LOCAL_INFILE = 1;

-- Import table for covid vaccinations following same pattern
SELECT * FROM alexcovid.covidvaccinations
ORDER BY 3, 4;

SET SQL_SAFE_UPDATES = 0;
DELETE FROM covidvaccinations;
SET SQL_SAFE_UPDATES = 1;

LOAD DATA LOCAL INFILE 'C:/Users/ABC/Desktop/DA/Alex Covid SQL/CovidVaccinations.csv'
INTO TABLE covidvaccinations
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

DESCRIBE coviddeaths;

-- date is in text format, we need to convert to date format by adding a new column and udpate it to date format
ALTER TABLE coviddeaths 
ADD COLUMN new_date DATE AFTER date;

UPDATE coviddeaths
SET new_date = STR_TO_DATE(date, '%m%d%Y %H:%i:%s');
SET SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES'; 

-- Select data to work with from covid deaths table
Select location, date, total_cases, new_cases, total_deaths, population
FROM Coviddeaths
order by 1,2;

-- Checking total cases vs total deaths to find likelihood of dying from covid in Nigeria
Select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
FROM Coviddeaths
Where location = 'Nigeria'
order by 1,2;

-- Checking total cases vs Population in Nigeria
Select location, cast(date as datetime), total_cases, population, (total_cases/population)*100 as CasesPercentage
FROM Coviddeaths
Where location = 'Nigeria'
order by 1,2;

-- Checking country with highest infection rate compared to population
Select location, population, max(total_cases) as HighestInfectionCount, max((total_cases/population))*100 as PercentPopulationInfected
FROM Coviddeaths
Where continent IS NOT NULL
Group by location, population
order by 4 DESC;

-- Highest Death Count per population by location
Select location, MAX(cast(total_deaths as unsigned)) as TotalDeathCount
FROM Coviddeaths
Where continent <> ''
Group by location
order by TotalDeathCount DESC;

-- Highest Death Count per population by continent
Select continent, MAX(cast(total_deaths as unsigned)) as TotalDeathCount
FROM Coviddeaths
Where continent <> ''
Group by continent
order by TotalDeathCount DESC;

-- Check Global Numbers
Select date, SUM(new_cases) as TotalCasesPerDay, SUM(cast(new_deaths as unsigned)) as TotalDeaths, (SUM(cast(new_deaths as unsigned))/SUM(new_cases))*100 as DeathPercentage
FROM Coviddeaths
Where continent <> ''
GROUP BY date
order by 1,2;

-- Check Total Population Vaccinated by Joining both tables and applying windows function
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations AS unsigned)) OVER (partition by dea.location order by dea.location, dea.date) AS RollingVaccinations
FROM coviddeaths dea
JOIN covidvaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent <> ''
ORDER BY 2,3;

-- Check Rollingvaccination/population as PopVsVac. This can't be executed in the same query because the numerator is an ALias.
-- However, this can be done with CTE or Temp Table. Let's start by using CTE

With PopvsVac (continent, location, date, population, new_vaccinations, rollingvaccinations)
as(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations AS unsigned)) OVER (partition by dea.location order by dea.location, dea.date) AS RollingVaccinations
FROM coviddeaths dea
JOIN covidvaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent <> ''
ORDER BY 2,3)
SELECT *, (Rollingvaccinations/Population)*100 as VacPerPop
FROM PopvsVac;

-- Using Temp table
Drop Table if exists PercentPopulationVaccinated;
Create Table PercentPopulationVaccinated
(
continent varchar(255),
location varchar(255),
date datetime,
population bigint,
new_vaccinations bigint,
rollingvaccinations float
);
Insert Into PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations AS unsigned)) OVER (partition by dea.location order by dea.location, dea.date) AS RollingVaccinations
FROM coviddeaths dea
JOIN covidvaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
;
SELECT *, (Rollingvaccinations/Population)*100 as VacPerPop
FROM PercentPopulationVaccinated;

-- Creating view to store data for later visualizations
Drop Table if exists PercentPopulationVaccinated;
Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(cast(vac.new_vaccinations AS unsigned)) OVER (partition by dea.location order by dea.location, dea.date) AS RollingVaccinations
FROM coviddeaths dea
JOIN covidvaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent <> '';	