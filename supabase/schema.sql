-- ===========================================================================
-- Cre8 — schéma de l'espace client (projet Supabase « qlicklab »).
--
-- Instantané de la base, pris sur l'état réellement appliqué. Il sert de
-- référence et permet de reconstruire l'ensemble sur un projet neuf ; la
-- source de vérité au quotidien reste l'historique de migrations Supabase.
--
-- Tout vit dans le schéma « public », sauf les fonctions d'aide des policies,
-- rangées dans « cre8_prive » : PostgREST n'expose pas ce schéma, donc ces
-- fonctions ne sont pas appelables via /rest/v1/rpc/, tout en gardant EXECUTE
-- pour le rôle « authenticated » — sans quoi les policies qui les appellent
-- échoueraient (Postgres vérifie EXECUTE sur le rôle qui interroge, même à
-- l'intérieur d'une policy).
-- ===========================================================================

create schema if not exists cre8_prive;
revoke all on schema cre8_prive from public;
grant usage on schema cre8_prive to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- 1. tables
-- ---------------------------------------------------------------------------
create table cre8_projets (
  id uuid not null default gen_random_uuid(),
  reference text not null,
  entreprise text not null,
  titre text not null default ''::text,
  resume text not null default ''::text,
  formule text not null default 'sur-mesure'::text,
  phase text not null default 'cadrage'::text,
  jour integer not null default 0,
  cycle integer not null default 14,
  avancement integer not null default 0,
  date_commande date,
  date_livraison date,
  devis_base numeric(10,2) not null default 0,
  montant_regle numeric(10,2) not null default 0,
  statut text not null default 'actif'::text,
  origine text not null default 'cre8'::text,
  origine_id uuid,
  cree_le timestamp with time zone not null default now(),
  maj_le timestamp with time zone not null default now(),
  code_acces text,
  constraint cre8_projets_avancement_check CHECK (((avancement >= 0) AND (avancement <= 100))),
  constraint cre8_projets_cycle_check CHECK ((cycle > 0)),
  constraint cre8_projets_devis_base_check CHECK ((devis_base >= (0)::numeric)),
  constraint cre8_projets_formule_check CHECK ((formule = ANY (ARRAY['catalogue'::text, 'sur-mesure'::text]))),
  constraint cre8_projets_jour_check CHECK ((jour >= 0)),
  constraint cre8_projets_montant_regle_check CHECK ((montant_regle >= (0)::numeric)),
  constraint cre8_projets_origine_check CHECK ((origine = ANY (ARRAY['cre8'::text, 'qlicklab'::text]))),
  constraint cre8_projets_phase_check CHECK ((phase = ANY (ARRAY['cadrage'::text, 'maquette'::text, 'developpement'::text, 'integration'::text, 'livraison'::text, 'termine'::text, 'pause'::text]))),
  constraint cre8_projets_statut_check CHECK ((statut = ANY (ARRAY['prospect'::text, 'actif'::text, 'pause'::text, 'livre'::text, 'archive'::text]))),
  constraint cre8_projets_pkey PRIMARY KEY (id),
  constraint cre8_projets_code_acces_key UNIQUE (code_acces),
  constraint cre8_projets_reference_key UNIQUE (reference)
);
alter table cre8_projets enable row level security;

create table cre8_comptes (
  id uuid not null,
  email text not null,
  nom text not null default ''::text,
  initiales text not null default ''::text,
  role text not null default 'client'::text,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_comptes_role_check CHECK ((role = ANY (ARRAY['client'::text, 'equipe'::text, 'admin'::text]))),
  constraint cre8_comptes_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  constraint cre8_comptes_pkey PRIMARY KEY (id)
);
alter table cre8_comptes enable row level security;

create table cre8_membres (
  projet_id uuid not null,
  compte_id uuid not null,
  role text not null default 'client'::text,
  ajoute_le timestamp with time zone not null default now(),
  constraint cre8_membres_role_check CHECK ((role = ANY (ARRAY['client'::text, 'equipe'::text]))),
  constraint cre8_membres_compte_id_fkey FOREIGN KEY (compte_id) REFERENCES cre8_comptes(id) ON DELETE CASCADE,
  constraint cre8_membres_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_membres_pkey PRIMARY KEY (projet_id, compte_id)
);
alter table cre8_membres enable row level security;

create table cre8_options (
  id text not null,
  nom text not null,
  texte text not null default ''::text,
  prix numeric(10,2) not null,
  jours integer not null default 0,
  recommandee boolean not null default false,
  actif boolean not null default true,
  rang integer not null default 100,
  constraint cre8_options_jours_check CHECK ((jours >= 0)),
  constraint cre8_options_prix_check CHECK ((prix >= (0)::numeric)),
  constraint cre8_options_pkey PRIMARY KEY (id)
);
alter table cre8_options enable row level security;

create table cre8_offres (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  auteur_id uuid,
  auteur_nom text not null default ''::text,
  titre text not null,
  texte text not null default ''::text,
  prix numeric(10,2) not null default 0,
  prix_avant numeric(10,2),
  jours integer not null default 0,
  valide_jusqu date,
  etat text not null default 'ouverte'::text,
  repondu_le timestamp with time zone,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_offres_etat_check CHECK ((etat = ANY (ARRAY['ouverte'::text, 'acceptee'::text, 'refusee'::text, 'expiree'::text]))),
  constraint cre8_offres_jours_check CHECK ((jours >= 0)),
  constraint cre8_offres_prix_avant_check CHECK ((prix_avant >= (0)::numeric)),
  constraint cre8_offres_prix_check CHECK ((prix >= (0)::numeric)),
  constraint cre8_offres_auteur_id_fkey FOREIGN KEY (auteur_id) REFERENCES cre8_comptes(id) ON DELETE SET NULL,
  constraint cre8_offres_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_offres_pkey PRIMARY KEY (id)
);
alter table cre8_offres enable row level security;

create table cre8_projet_options (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  option_id text,
  nom text not null,
  prix numeric(10,2) not null,
  jours integer not null default 0,
  statut text not null default 'panier'::text,
  paye_le timestamp with time zone,
  cree_le timestamp with time zone not null default now(),
  offre_id uuid,
  constraint cre8_projet_options_prix_check CHECK ((prix >= (0)::numeric)),
  constraint cre8_projet_options_statut_check CHECK ((statut = ANY (ARRAY['panier'::text, 'payee'::text, 'annulee'::text]))),
  constraint cre8_projet_options_offre_id_fkey FOREIGN KEY (offre_id) REFERENCES cre8_offres(id) ON DELETE SET NULL,
  constraint cre8_projet_options_option_id_fkey FOREIGN KEY (option_id) REFERENCES cre8_options(id) ON DELETE SET NULL,
  constraint cre8_projet_options_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_projet_options_pkey PRIMARY KEY (id)
);
alter table cre8_projet_options enable row level security;
create index if not exists cre8_projet_options_offre_idx
  on cre8_projet_options (offre_id) where offre_id is not null;

create table cre8_messages (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  auteur_id uuid,
  auteur_nom text not null default ''::text,
  role text not null default 'client'::text,
  type text not null default 'message'::text,
  texte text not null default ''::text,
  offre_id uuid,
  lu_le timestamp with time zone,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_messages_offre_coherente CHECK (((type = 'offre'::text) = (offre_id IS NOT NULL))),
  constraint cre8_messages_role_check CHECK ((role = ANY (ARRAY['client'::text, 'equipe'::text, 'systeme'::text]))),
  constraint cre8_messages_type_check CHECK ((type = ANY (ARRAY['message'::text, 'offre'::text, 'systeme'::text]))),
  constraint cre8_messages_auteur_id_fkey FOREIGN KEY (auteur_id) REFERENCES cre8_comptes(id) ON DELETE SET NULL,
  constraint cre8_messages_offre_id_fkey FOREIGN KEY (offre_id) REFERENCES cre8_offres(id) ON DELETE CASCADE,
  constraint cre8_messages_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_messages_pkey PRIMARY KEY (id)
);
alter table cre8_messages enable row level security;

create table cre8_actions (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  kind text not null default 'info'::text,
  texte text not null,
  detail text not null default ''::text,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_actions_kind_check CHECK ((kind = ANY (ARRAY['info'::text, 'jalon'::text, 'alerte'::text, 'paiement'::text]))),
  constraint cre8_actions_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_actions_pkey PRIMARY KEY (id)
);
alter table cre8_actions enable row level security;

create table cre8_taches (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  titre text not null,
  detail text not null default ''::text,
  faite boolean not null default false,
  faite_le timestamp with time zone,
  echeance date,
  rang integer not null default 100,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_taches_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_taches_pkey PRIMARY KEY (id)
);
alter table cre8_taches enable row level security;

create table cre8_factures (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  reference text not null,
  libelle text not null,
  montant numeric(10,2) not null,
  etat text not null default 'attente'::text,
  echeance date,
  paye_le timestamp with time zone,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_factures_etat_check CHECK ((etat = ANY (ARRAY['attente'::text, 'payee'::text, 'annulee'::text]))),
  constraint cre8_factures_montant_check CHECK ((montant >= (0)::numeric)),
  constraint cre8_factures_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_factures_pkey PRIMARY KEY (id),
  constraint cre8_factures_reference_key UNIQUE (reference)
);
alter table cre8_factures enable row level security;

create table cre8_documents (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  nom text not null,
  mime text not null default ''::text,
  taille bigint not null default 0,
  chemin text not null default ''::text,
  url text not null default ''::text,
  note text not null default ''::text,
  depose_par text not null default 'client'::text,
  cree_le timestamp with time zone not null default now(),
  origine_id uuid,
  constraint cre8_documents_depose_par_check CHECK ((depose_par = ANY (ARRAY['client'::text, 'equipe'::text]))),
  constraint cre8_documents_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_documents_pkey PRIMARY KEY (id)
);
alter table cre8_documents enable row level security;

create table cre8_liens (
  id uuid not null default gen_random_uuid(),
  projet_id uuid not null,
  libelle text not null,
  url text not null,
  kind text not null default 'autre'::text,
  cree_le timestamp with time zone not null default now(),
  constraint cre8_liens_kind_check CHECK ((kind = ANY (ARRAY['prod'::text, 'preprod'::text, 'maquette'::text, 'depot'::text, 'autre'::text]))),
  constraint cre8_liens_projet_id_fkey FOREIGN KEY (projet_id) REFERENCES cre8_projets(id) ON DELETE CASCADE,
  constraint cre8_liens_pkey PRIMARY KEY (id)
);
alter table cre8_liens enable row level security;

-- Journal des codes d'accès essayés, pour limiter le forçage.
-- RLS activée SANS aucune policy : c'est voulu. Seule cre8_rejoindre_projet(),
-- en SECURITY DEFINER, la lit et l'écrit ; aucun client ne peut la consulter.
create table cre8_essais_code (
  compte_id uuid not null,
  essaye_le timestamp with time zone not null default now(),
  constraint cre8_essais_code_compte_id_fkey FOREIGN KEY (compte_id) REFERENCES auth.users(id) ON DELETE CASCADE
);
alter table cre8_essais_code enable row level security;
create index if not exists cre8_essais_code_idx on cre8_essais_code (compte_id, essaye_le desc);

-- ---------------------------------------------------------------------------
-- 2. fonctions
-- ---------------------------------------------------------------------------
create or replace function cre8_prive.est_equipe() returns boolean
  language sql stable security definer set search_path to 'public', 'pg_temp'
as $$
  select exists (
    select 1 from cre8_comptes
    where id = auth.uid() and role in ('equipe','admin')
  );
$$;

create or replace function cre8_prive.membre_de(p_projet uuid) returns boolean
  language sql stable security definer set search_path to 'public', 'pg_temp'
as $$
  select cre8_prive.est_equipe() or exists (
    select 1 from cre8_membres
    where projet_id = p_projet and compte_id = auth.uid()
  );
$$;

revoke all on function cre8_prive.est_equipe()    from public;
revoke all on function cre8_prive.membre_de(uuid) from public;
grant execute on function cre8_prive.est_equipe()    to authenticated, service_role;
grant execute on function cre8_prive.membre_de(uuid) to authenticated, service_role;

-- Création automatique de la fiche compte à l'inscription (e-mail comme Google).
create or replace function cre8_prive.nouveau_compte() returns trigger
  language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_nom text;
  v_ini text;
begin
  v_nom := coalesce(
    nullif(new.raw_user_meta_data->>'full_name', ''),
    nullif(new.raw_user_meta_data->>'name', ''),
    split_part(new.email, '@', 1)
  );
  v_ini := upper(
    left(split_part(v_nom, ' ', 1), 1) ||
    coalesce(nullif(left(split_part(v_nom, ' ', 2), 1), ''), '')
  );

  insert into cre8_comptes (id, email, nom, initiales)
  values (new.id, new.email, v_nom, v_ini)
  on conflict (id) do nothing;

  return new;
end;
$$;
revoke all on function cre8_prive.nouveau_compte() from public;

create or replace function public.cre8_touch() returns trigger
  language plpgsql set search_path to 'public', 'pg_temp'
as $$
begin
  new.maj_le = now();
  return new;
end;
$$;
grant execute on function public.cre8_touch() to authenticated, anon, service_role;

-- Passerelle Qlicklab -> Cre8 : le client saisit le code d'accès qu'il
-- utilisait auparavant et son compte est rattaché au projet repris.
-- SECURITY DEFINER et exposée à « authenticated » : c'est voulu, c'est la seule
-- porte d'entrée pour reprendre un dossier. anon n'y a pas accès, et les essais
-- sont limités à 10 par heure et par compte.
create or replace function public.cre8_rejoindre_projet(p_code text)
  returns table(reference text, entreprise text)
  language plpgsql security definer set search_path to 'public', 'pg_temp'
as $$
declare
  v_projet uuid;
  v_essais int;
begin
  if auth.uid() is null then
    raise exception 'non connecté' using errcode = '28000';
  end if;

  select count(*) into v_essais
  from cre8_essais_code
  where compte_id = auth.uid() and essaye_le > now() - interval '1 hour';

  if v_essais >= 10 then
    raise exception 'trop d''essais' using errcode = '54000';
  end if;

  insert into cre8_essais_code (compte_id) values (auth.uid());

  select p.id into v_projet
  from cre8_projets p
  where p.code_acces = regexp_replace(coalesce(p_code, ''), '\s', '', 'g')
    and p.statut = 'actif';

  if v_projet is null then
    raise exception 'code inconnu' using errcode = 'P0002';
  end if;

  insert into cre8_membres (projet_id, compte_id, role)
  values (v_projet, auth.uid(), 'client')
  on conflict (projet_id, compte_id) do nothing;

  -- l'essai réussi ne compte pas contre le quota
  delete from cre8_essais_code
  where ctid = (select ctid from cre8_essais_code
                where compte_id = auth.uid() order by essaye_le desc limit 1);

  return query
    select p.reference, p.entreprise from cre8_projets p where p.id = v_projet;
end;
$$;
revoke all on function public.cre8_rejoindre_projet(text) from public, anon;
grant execute on function public.cre8_rejoindre_projet(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. triggers
-- ---------------------------------------------------------------------------
create trigger cre8_projets_touch before update on public.cre8_projets
  for each row execute function cre8_touch();

create trigger cre8_on_auth_user_created after insert on auth.users
  for each row execute function cre8_prive.nouveau_compte();

-- ---------------------------------------------------------------------------
-- 4. politiques RLS
--
-- Principe : l'équipe gère tout ; le client ne voit que les projets dont il est
-- membre, et n'a le droit d'écrire que trois choses — un message signé de lui,
-- une ligne dans son panier, et une réponse (acceptée / refusée) à une offre
-- encore ouverte. Il ne peut ni fixer un prix, ni créer une offre, ni se faire
-- passer pour l'équipe.
-- ---------------------------------------------------------------------------
create policy "compte: je lis le mien, l'équipe lit tout" on cre8_comptes for select to authenticated
  using (id = auth.uid() or cre8_prive.est_equipe());
create policy "compte: je modifie le mien" on cre8_comptes for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid()
              and role = (select c.role from cre8_comptes c where c.id = auth.uid()));

create policy "projet: mes projets" on cre8_projets for select to authenticated
  using (cre8_prive.membre_de(id));
create policy "projet: l'équipe écrit" on cre8_projets for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "membre: je vois les miens, l'équipe voit tout" on cre8_membres for select to authenticated
  using (compte_id = auth.uid() or cre8_prive.est_equipe());
create policy "membre: l'équipe gère" on cre8_membres for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "option: lisible par tout compte connecté" on cre8_options for select to authenticated
  using (actif or cre8_prive.est_equipe());
create policy "option: l'équipe gère" on cre8_options for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "projet_option: lecture selon le projet" on cre8_projet_options for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "projet_option: le client remplit son panier" on cre8_projet_options for insert to authenticated
  with check (cre8_prive.membre_de(projet_id) and statut = 'panier');
create policy "projet_option: le client retire de son panier" on cre8_projet_options for delete to authenticated
  using (cre8_prive.membre_de(projet_id) and statut = 'panier');
create policy "projet_option: l'équipe gère" on cre8_projet_options for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "offre: lecture selon le projet" on cre8_offres for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "offre: seule l'équipe en crée" on cre8_offres for insert to authenticated
  with check (cre8_prive.est_equipe());
-- le client bascule une offre ouverte vers acceptée ou refusée, et rien d'autre
create policy "offre: le client répond" on cre8_offres for update to authenticated
  using (cre8_prive.membre_de(projet_id) and etat = 'ouverte')
  with check (etat in ('acceptee','refusee'));
create policy "offre: l'équipe gère" on cre8_offres for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "message: lecture selon le projet" on cre8_messages for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "message: j'écris sur mes projets" on cre8_messages for insert to authenticated
  with check (cre8_prive.membre_de(projet_id)
              and auteur_id = auth.uid()
              and (role <> 'equipe' or cre8_prive.est_equipe()));
create policy "message: l'équipe gère" on cre8_messages for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "action: lecture selon le projet" on cre8_actions for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "action: l'équipe gère" on cre8_actions for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "tache: lecture selon le projet" on cre8_taches for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "tache: l'équipe gère" on cre8_taches for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "facture: lecture selon le projet" on cre8_factures for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "facture: l'équipe gère" on cre8_factures for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "document: lecture selon le projet" on cre8_documents for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "document: le client dépose" on cre8_documents for insert to authenticated
  with check (cre8_prive.membre_de(projet_id) and depose_par = 'client');
create policy "document: l'équipe gère" on cre8_documents for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());

create policy "lien: lecture selon le projet" on cre8_liens for select to authenticated
  using (cre8_prive.membre_de(projet_id));
create policy "lien: l'équipe gère" on cre8_liens for all to authenticated
  using (cre8_prive.est_equipe()) with check (cre8_prive.est_equipe());
