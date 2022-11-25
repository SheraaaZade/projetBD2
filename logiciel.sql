DROP SCHEMA IF EXISTS logiciel CASCADE;
CREATE SCHEMA logiciel;

CREATE TABLE logiciel.cours
(
    id_cours         SERIAL PRIMARY KEY,
    code_cours       VARCHAR(8) UNIQUE NOT NULL CHECK ( code_cours SIMILAR TO 'BINV[0-9]{4}'),
    nom              VARCHAR(100)      NOT NULL CHECK (nom <> '' AND nom <> ' '),
    bloc             INTEGER           NOT NULL CHECK ( bloc >= 1 AND bloc <= 3 ),
    nombre_credits   INTEGER           NOT NULL CHECK ( nombre_credits > 0 ),
    nombre_etudiants INTEGER           NOT NULL DEFAULT 0
);

CREATE TABLE logiciel.projets
(
    num_projet         SERIAL PRIMARY KEY,
    identifiant_projet CHAR(50)                                     NOT NULL UNIQUE CHECK ( identifiant_projet <> '' AND identifiant_projet <> ' '),
    nom                VARCHAR(100)                                 NOT NULL CHECK (nom <> '' AND nom <> ' '),
    date_debut         DATE                                         NOT NULL DEFAULT current_date,
    date_fin           DATE                                         NOT NULL DEFAULT current_date,
    nombre_groupe      INTEGER                                      NOT NULL CHECK (nombre_groupe >= 0),
    cours              INTEGER REFERENCES logiciel.cours (id_cours) NOT NULL,
    CHECK (date_fin > date_debut)
);

CREATE TABLE logiciel.etudiants
(
    id_etudiant SERIAL PRIMARY KEY,
    nom         VARCHAR(100) NOT NULL CHECK (nom <> '' AND nom <> ' '),
    prenom      VARCHAR(100) NOT NULL CHECK (prenom <> '' AND prenom <> ' '),
    mail        VARCHAR(250) NOT NULL CHECK ( mail SIMILAR TO '%_@student.vinci.be'),
    pass_word   VARCHAR(100) NOT NULL CHECK ( pass_word <> '' AND pass_word <> ' ')
);

CREATE TABLE logiciel.inscriptions_cours
(
    id_inscription_cours SERIAL PRIMARY KEY,
    cours                INTEGER REFERENCES logiciel.cours (id_cours)        NOT NULL,
    etudiant             INTEGER REFERENCES logiciel.etudiants (id_etudiant) NOT NULL,
    UNIQUE (cours, etudiant)
);

CREATE TABLE logiciel.groupes
(
    id_groupe       SERIAL PRIMARY KEY,-- CHECK( num_groupe <= logiciel.projets.nombre_groupe), -- REINITIALISER A 1 POUR UN NOUVEAU PROJET
    num_groupe      INTEGER                                          NOT NULL,
    taille_groupe   INTEGER                                          NOT NULL CHECK ( taille_groupe > 0),--CHECK (( nombre_place * logiciel.projets.nombre_groupe) <= logiciel.cours.nombre_etudiants ),
    nombre_inscrits INTEGER                                          NOT NULL CHECK (nombre_inscrits >= 0) DEFAULT 0,
    valide          BOOLEAN                                          NOT NULL                              DEFAULT FALSE,
    complet         BOOLEAN                                          NOT NULL                              DEFAULT FALSE,
    projet          INTEGER REFERENCES logiciel.projets (num_projet) NOT NULL
);
CREATE TABLE logiciel.inscriptions_groupes
(
    id_inscription_groupe SERIAL PRIMARY KEY,
    etudiant              INTEGER REFERENCES logiciel.etudiants (id_etudiant) NOT NULL,
    groupe                INTEGER REFERENCES logiciel.groupes (id_groupe)     NOT NULL,
    projet                INTEGER REFERENCES logiciel.projets (num_projet)    NOT NULL,
    UNIQUE (etudiant, groupe)
);

-- INSERT INTO logiciel.cours(code_cours, nom, bloc, nombre_credits, nombre_etudiants)
-- VALUES('BINV4785','Atelier Java', 2, 6, 5);
-- INSERT INTO logiciel.cours(code_cours, nom, bloc, nombre_credits, nombre_etudiants)
-- VALUES('BINV1660','UML', 2, 4, 15);
--
-- INSERT INTO logiciel.projets(identifiant_projet, nom,  date_fin, nombre_groupe, cours)
-- VALUES('ABCDEF','PAE','2023/06/01',5,1);
-- INSERT INTO logiciel.projets(identifiant_projet, nom,  date_fin, nombre_groupe, cours)
-- VALUES('EFG','Diagramme de classe','2023/03/01',3,2);

--PRIORITE 1
CREATE FUNCTION logiciel.insererEtudiant(_nom char(100), _prenom char(100), _mail char(250), _password char(100))
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO logiciel.etudiants(nom, prenom, mail, pass_word) VALUES (_nom, _prenom, _mail, _password);
end;
$$ LANGUAGE plpgsql;

select logiciel.insererEtudiant('Zade', 'Shera', 'chehrazad.ouazzani@student.vinci.be', 'BONJOUR');

CREATE FUNCTION logiciel.insererCours(_code_cours char(8), _nom char(100), _bloc INTEGER, _nb_credits INTEGER,
                                      _nb_etudiant INTEGER)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO logiciel.cours VALUES (_code_cours, _nom, _bloc, _nb_credits, _nb_etudiant);
end;
$$ LANGUAGE plpgsql;

--PRIORITE 2
CREATE FUNCTION logiciel.insererProjets(_identifiant_projet char(50), _nom char(100), _date_debut DATE, _date_fin DATE,
                                        _nb_groupe INTEGER, _cours INTEGER)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO logiciel.projets(identifiant_projet, nom, date_debut, date_fin, nombre_groupe, cours)
    VALUES (_identifiant_projet, _nom, _date_debut, _date_fin, _nb_groupe, _cours);
end;
$$ LANGUAGE plpgsql;

CREATE FUNCTION logiciel.inscrireEtudiantCours(_cours INTEGER, _etudiant INTEGER)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO logiciel.inscriptions_cours(cours, etudiant) VALUES (_cours, _etudiant);
end;
$$ LANGUAGE plpgsql;

--PRIORITE 3
CREATE FUNCTION logiciel.creerGroupe(_num_groupe INTEGER, _taille_groupe INTEGER,
                                     _nb_inscrits INTEGER, _valide BOOLEAN, _complet BOOLEAN, _projet INTEGER)
    RETURNS VOID AS
$$
DECLARE
    nombre_etudiant INTEGER;
    capacite        INTEGER;

BEGIN

    SELECT SUM(groupe.taille_groupe)
    FROM logiciel.cours cours,
         logiciel.groupes groupe,
         logiciel.projets projet
    WHERE projet.cours = cours.id_cours
      AND groupe.projet = projet.num_projet
    INTO capacite;

    IF (nombre_etudiant > logiciel.cours.nombre_etudiants) THEN
        RAISE 'erreur nombre inscrit ne peut pas dépasser le nombre de place !';
    end if;


    INSERT INTO logiciel.groupes(num_groupe, nombre_inscrits, taille_groupe, valide, complet, projet)
    VALUES (_num_groupe, _nb_inscrits, _taille_groupe, _valide, _complet, _projet);
end;

$$ LANGUAGE plpgsql;

--PRIORITE 4
CREATE FUNCTION logiciel.inscrireEtudiantGroupe(_etudiant INTEGER, _groupe INTEGER, _projet INTEGER)
    RETURNS VOID AS
$$
BEGIN
    INSERT INTO logiciel.inscriptions_groupes(etudiant, groupe, projet) VALUES (_etudiant, _groupe, _projet);
end;
$$ LANGUAGE plpgsql;

CREATE FUNCTION logiciel.trigger1()
    RETURNS TRIGGER AS
$$
DECLARE
    total_etudiant INTEGER;
BEGIN
    SELECT SUM(groupe.nombre_inscrits)
    FROM logiciel.cours cours,
         logiciel.groupes groupe,
         logiciel.projets projet
    WHERE projet.cours = cours.id_cours
      AND groupe.projet = projet.num_projet
    INTO total_etudiant;
    IF (total_etudiant != logiciel.cours.nombre_etudiants) THEN
        RAISE 'erreur somme des tailles de groupes doit être égal au nombre!';
    end if;
end;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_place_disponible_groupe
    AFTER INSERT
    on logiciel.inscriptions_groupes FOR EACH ROW
EXECUTE PROCEDURE logiciel.trigger1();

CREATE TRIGGER trigger_creation_groupe
    AFTER INSERT
    on logiciel.groupes FOR EACH ROW
EXECUTE PROCEDURE logiciel.trigger1();