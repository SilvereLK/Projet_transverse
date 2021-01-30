-- 1/  Etude globale

--  a/ Répartion Adhérant / VIP

-- Compte le nombre client avec un code VIP = 1
select distinct count(idclient) as Client_VIP from client where vip=1;
--110451

-- Compte le nombre de client avec une date  de début adhesion = '2016'
select distinct count(idclient) as Client_NEW_N2 from client where extract(year from datedebutadhesion)=2016;
--135736

-- Compte le nombre de client avec une date de début adhesion = '2017'
select distinct count(idclient) as Client_NEW_N1 from client where extract(year from datedebutadhesion)=2017;
--136815

-- Compte le nombre de client avec une date fin adhesion > '2018/01/01'
select distinct count(idclient) as Client_ADHÉRENT from client where datefinadhesion>'2018-01-01';
--452876

-- Compte le nombre de client avec une date fin adhesion < '2018/01/01'
select distinct count(idclient) as Client_CHURNER from client where datefinadhesion<'2018-01-01';
--393000


--   b/CA GLOBAL

-- Calcul du CA par client et par année
select idclient, extract(year from tic_date) as ticket_date, sum(tic_totalttc) as ca_global
from entete_ticket
group by idclient, ticket_date
order by ticket_date

--- c/ Répartition par âge par sexe

-- Création de la variable tranche_age pour le graphique Pyramide qui montre mieux la répartition par âge x sexe sur l'ensemble des clients:
ALTER TABLE client add tranche_age varchar
UPDATE client set tranche_age = (case 
					when age between 0 and 4 then 'A,0-4'
					when age between 5 and 9 then 'B,5-9'
					when  age between 10 and 14then 'C,10-14'
					when age between 15 and 19 then 'D,15-19'
					when age between 20 and 24 then 'E,20-24'
					when age between 25 and 29 then 'F,25-29'
					when age between 30 and 34then 'G,30-34'
					when age between 35 and 39then 'H,35-39'
					when age between 40 and 44 then 'I,40-44'
					when age between 45 and 49 then 'G,45-49'
					when age between 50 and 54 then 'K,50-54'
					when age between 55 and 59 then 'L,55-59'
					when age between 60 and 64 then 'M,60-64'
					when age between 65 and 69 then 'N,65-69'
					when age between 70 and 79 then 'O,70-74'
					when age between 75 and 79 then 'P,75-79'
					when age between 80 and 84 then 'Q,80-84'
					when age between 85 and 89 then 'R,85-89'
					when age between 90 and 94 then 'S,90-94'
					when age between 95 and 99 then 'T,95-99'	
	end);

--PS: Rajouter des caractères avec les tranches d'age afin de les afficher par ordre alphabétique sur la table

-- Requete principale: count le nombre de client par tranche d'âge
select distinct count(civilite),SPLIT_PART(tranche_age,',','2') as tranche_age,civilite as sexe, SPLIT_PART(tranche_age,',','1') as ordre from client
where tranche_age is not null
group by tranche_age,civilite
order by ordre 

--Requete pour pivoter les 2 valeurs (Monsieur,Madame) de la variable civilite(sexe) en 2 variables (Homme,Femme) : CrossTab (Pivot) :
select SPLIT_PART(tranche_age,',','1') as ordre,SPLIT_PART(tranche_age,',','2') as tranche_age, 
	count(Case civilite when 'Monsieur' then civilite end) as Homme,
    	count(Case civilite when 'Madame' then civilite end) as Femme
	from client
	where tranche_age is not null
	group by tranche_age
	order by ordre


-- 2/ Etude magasin

--   a/ Résultat par magasin

--Grouper chaque magasin par nombres de clients.-----
select mag_code,count(idclient) from entete_ticket
group by mag_code  order by mag_code asc ;

----Total TTC N-2---
select mag_code, sum(TIC_Totalttc) from entete_ticket
where extract(Year from TIC_date)=2016
group by mag_code  order by mag_code asc ;

----Total TTC N-1-----
select mag_code, sum(TIC_Totalttc) from entete_ticket
where extract(Year from TIC_date)=2017
group by mag_code  order by mag_code asc ;


--      b/ Distance client magasin

-- Création de la table DataInsee contenant les données Insee
-- Afin de rentre les données totalement utilisable, le fichier exporté depuis le site du gouvernement a subit un process de data quality
drop table IF EXISTS DataInsee;
create table DataInsee
(
	Code_INSEE varchar(10) primary key,
	Code_Postal varchar(50),
	Commune varchar(50),
	Département varchar (50),
	Région varchar (50),
	Statut varchar (50),
	Altitude_Moyenne real,
	Superficie real,
	Population real,
	geo_point_2d varchar (100),
	geo_shape text,
	ID_Geofla int,
	Code_Commune int,
	Code_Canton int,
	Code_Arrondissement int,
	Code_Departement varchar(50),
	Code_Region varchar(50)
);

COPY DataInsee FROM 'C:\DATA_Projet_Transverse\CP_Insee_V2.csv' CSV HEADER delimiter ';' null '';

select *  from DataInsee
limit 50;

--- Extration des longitude lattitude 

/****** Client*********/

select c.idclient, c.codeinsee insee_client,di.code_insee insee_gouv, SPLIT_PART(di.geo_point_2d,',',1) as longitude,
SPLIT_PART(di.geo_point_2d,',',2) as lagitude

from client as c

left join datainsee as di on c.codeinsee = di.code_insee

where c.codeinsee is not null
and di.code_insee is not null

/****** Magasin*****/

select mag.codesociete, mag.ville,di.commune ,SPLIT_PART(di.geo_point_2d,',',1) as longitude,
SPLIT_PART(di.geo_point_2d,',',2) as lagitude

from ref_magasin as mag

left join datainsee as di on (TRIM(mag.ville) = TRIM(di.commune)
							  and mag.libelledepartement = CAST(di.code_departement as integer))

where mag.ville is not null
and di.commune is not null;


--- Crétaion de la fonction de calcul de distance

/****** FUNCTION Distance ******/

Create or replace function distance(real,real,real,real) 
Returns real 
as 
$dist$
DECLARE 
	rlo1 real;
	rla1 real;
	rlo2 real;
	rla2 real;
	dla real;
	dlo real;
	cal real;
	dist real;
	distterre CONSTANT INTEGER := 6378137; /*sphère de la terre en raduis*/
		
BEGIN
		/*convertion en raduis des paramètres qui sont en degré*/
		rlo1 := ($1 * (3.14 / 180));
      	rla1 := $2 * (3.14 / 180) ;
      	rlo2 := $3 * (3.14 / 180) ;
      	rla2 := $4 * (3.14 / 180);
		/********************************/
		
      	dlo := (rlo2 - rlo1) / 2;
      	dla := (rla2 - rla1) / 2;
		
      cal := (sin(dla) * sin(dla)) + cos(rla1) * cos(rla2) * (sin(dlo) * sin(dlo));
      dist := 2 * atan2(sqrt(cal), sqrt(1 - cal));
	  return dist*distterre/1000; /*** Distance en Km*/
	END;
$dist$ 
LANGUAGE plpgsql;


---- Requête de calul de la distance magasin client --------

select c.idclient, mag.codesociete,
SPLIT_PART(di_client.geo_point_2d,',',1) as longitude_client,
SPLIT_PART(di_client.geo_point_2d,',',2) as lattitude_client,
SPLIT_PART(di_magasin.geo_point_2d,',',1) as longitude_magasin,
SPLIT_PART(di_magasin.geo_point_2d,',',2) as lattitude_magasin,
 --calcul de la distance-
distance(CAST(SPLIT_PART(di_client.geo_point_2d,',',1) as real),CAST(SPLIT_PART(di_client.geo_point_2d,',',2) as real),
		CAST(SPLIT_PART(di_magasin.geo_point_2d,',',1) as real),CAST(SPLIT_PART(di_magasin.geo_point_2d,',',2) as real))

from client as c
left join ref_magasin as mag on (c.magasin = mag.codesociete)
left join datainsee as di_client on c.codeinsee = di_client.code_insee
left join datainsee as di_magasin on (TRIM(mag.ville) = TRIM(di_magasin.commune)
							  and mag.libelledepartement = CAST(di_magasin.code_departement as integer))


where c.codeinsee is not null
and di_client.code_insee is not null
and mag.ville is not null
and di_magasin.commune is not null;



----           3/Etude par Univers
------      a/Etude par univers

-- Extraction de du CA de l'année N-1 Par univers
select SUM(et.tic_totalttc) as CA, ar.codeunivers, extract(year from et.tic_date) as Annee
from entete_ticket as et
inner join lignes_ticket as lt on et.idticket = lt.idticket
left join ref_article as ar on lt.idarticle = ar.codearticle
where extract(year from et.tic_date) = 2017
group by ar.codeunivers,extract(year from et.tic_date)

UNION all

-- Extraction de du CA de l'année N-2 Par univers
select SUM(et.tic_totalttc) as CA, ar.codeunivers,extract(year from et.tic_date) as Annee
from entete_ticket as et
inner join lignes_ticket as lt on et.idticket = lt.idticket
left join ref_article as ar on lt.idarticle = ar.codearticle
where extract(year from tic_date) = 2016
group by ar.codeunivers,extract(year from et.tic_date);


---        b/ Top Par Univers

 -- Calcul la somme des marge de sortie par famille et par univers
select SUM(lt.margesortie) as Marge ,ar.codeunivers,ar.codefamille
from entete_ticket as et
inner join lignes_ticket as lt on et.idticket = lt.idticket
left join ref_article as ar on lt.idarticle = ar.codearticle
group by ar.codeunivers,ar.codefamille
