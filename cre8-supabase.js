/* ===========================================================================
   cre8-supabase.js — configuration et accès aux données.
   Partagé par connexion.html et espace.html.

   La clé ci-dessous est *publiable* : elle est faite pour vivre dans le
   navigateur. Elle n'ouvre que ce que les politiques RLS autorisent au compte
   connecté — sans session, elle ne donne accès à rien d'autre qu'au catalogue
   d'options. Les fonctions sensibles vivent dans le schéma « cre8_prive »,
   que l'API n'expose pas.
   =========================================================================== */
(function (w) {
'use strict';

var CONF = {
  url: 'https://dqqhoaviihpxqlrqefwm.supabase.co',
  cle: 'sb_publishable_d2g7me4Gu5I4Ry_X81tjag_w8Kkt9Im'
};

/* Le SDK est chargé par une balise <script> avant celle-ci. S'il manque
   (réseau coupé, CDN bloqué), on le dit au lieu de planter en silence. */
if (!w.supabase || !w.supabase.createClient) {
  w.CRE8 = {
    absent: true,
    messageErreur: function () {
      return 'Le module de connexion n’a pas pu être chargé. Vérifiez votre réseau, puis rechargez la page.';
    }
  };
  return;
}

/* « Rester connecté sur cet appareil ».
   Coché : la session va dans localStorage et survit à la fermeture du
   navigateur. Décoché : sessionStorage, donc elle meurt avec l'onglet.
   L'adaptateur relit le choix à chaque accès, ce qui permet de le changer
   après la création du client — que supabase-js ne laisse pas reconfigurer. */
var CLE_MEM = 'cre8_memoriser';

function memorise() {
  try { return localStorage.getItem(CLE_MEM) !== '0'; }
  catch (e) { return false; }
}
function memoriser(oui) {
  try { localStorage.setItem(CLE_MEM, oui ? '1' : '0'); } catch (e) {}
}
function coffre() {
  try { return memorise() ? w.localStorage : w.sessionStorage; }
  catch (e) { return null; }
}

var stockage = {
  getItem:    function (k) { try { var s = coffre(); return s ? s.getItem(k) : null; } catch (e) { return null; } },
  setItem:    function (k, v) { try { var s = coffre(); if (s) s.setItem(k, v); } catch (e) {} },
  // au retrait, on nettoie les deux : le choix a pu changer entre-temps
  removeItem: function (k) {
    try { w.localStorage.removeItem(k); } catch (e) {}
    try { w.sessionStorage.removeItem(k); } catch (e) {}
  }
};

var sb = w.supabase.createClient(CONF.url, CONF.cle, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: stockage
  }
});

/* URL du dossier courant, pour les retours OAuth et les liens de courriel. */
function base() { return location.href.replace(/[?#].*$/, '').replace(/[^/]*$/, ''); }

/* ---------------------------------------------------------------------------
   Messages d'erreur : Supabase répond en anglais, le site parle français.
   --------------------------------------------------------------------------- */
var TRAD = [
  [/invalid login credentials/i,        'E-mail ou mot de passe incorrect.'],
  [/email not confirmed/i,              'Il reste à confirmer votre e-mail : le lien est dans votre boîte de réception.'],
  [/already registered|already exists/i,'Un compte existe déjà avec cet e-mail. Connectez-vous plutôt.'],
  [/password should be at least/i,      'Le mot de passe doit faire au moins 8 caractères.'],
  [/weak password/i,                    'Ce mot de passe est trop simple. Ajoutez une majuscule ou un chiffre.'],
  [/rate limit|too many requests/i,     'Trop de tentatives. Patientez quelques minutes.'],
  [/provider is not enabled/i,          'La connexion Google n’est pas encore activée sur ce projet.'],
  [/code inconnu/i,                     'Ce code d’accès ne correspond à aucun projet en cours.'],
  [/trop d.essais/i,                    'Trop de codes essayés. Réessayez dans une heure.'],
  [/non connect/i,                      'Votre session a expiré. Reconnectez-vous.'],
  [/failed to fetch|networkerror|load failed/i,
                                        'Connexion au serveur impossible. Vérifiez votre réseau puis réessayez.']
];

function messageErreur(e) {
  var m = (e && (e.message || e.error_description || e.msg)) || '';
  for (var i = 0; i < TRAD.length; i++) if (TRAD[i][0].test(m)) return TRAD[i][1];
  return m ? ('Erreur : ' + m) : 'Une erreur est survenue. Réessayez.';
}

function verifier(r) {
  if (r && r.error) throw r.error;
  return r ? r.data : null;
}

/* ---------------------------------------------------------------------------
   Authentification
   --------------------------------------------------------------------------- */
function session() {
  return sb.auth.getSession().then(function (r) {
    return (r.data && r.data.session) || null;
  });
}

function connexion(email, motdepasse) {
  return sb.auth.signInWithPassword({ email: email, password: motdepasse }).then(verifier);
}

/* `extra` porte les coordonnées demandées par le tunnel de commande
   (téléphone, société, secteur) : le trigger les recopie sur la fiche. */
function inscription(nom, email, motdepasse, extra) {
  var meta = { full_name: nom };
  if (extra) {
    if (extra.telephone) meta.telephone = extra.telephone;
    if (extra.societe)   meta.societe   = extra.societe;
    if (extra.secteur)   meta.secteur   = extra.secteur;
  }
  return sb.auth.signUp({
    email: email,
    password: motdepasse,
    options: { data: meta, emailRedirectTo: base() + 'espace.html' }
  }).then(verifier);
}

/* Fiche du compte connecté, ou null. Sert au tunnel de commande pour
   préremplir les coordonnées sans les redemander. */
function profil() {
  return session().then(function (s) {
    if (!s) return null;
    return compteCourant(s).then(function (c) {
      return {
        id: c.id, email: c.email, nom: c.nom,
        initiales: c.initiales || '', photo: c.avatar_url || '',
        tel: c.telephone || '', societe: c.societe || '', secteur: c.secteur || ''
      };
    });
  });
}

/* Renvoie true si le compte est créé et déjà utilisable, false s'il faut
   d'abord confirmer l'e-mail (selon le réglage du projet Supabase). */
function inscriptionOuverte(d) {
  return !!(d && d.session);
}

function google() {
  return sb.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: base() + 'espace.html' }
  }).then(verifier);
}

function motDePasseOublie(email) {
  return sb.auth.resetPasswordForEmail(email, {
    redirectTo: base() + 'connexion.html'
  }).then(verifier);
}

function deconnexion() {
  return sb.auth.signOut();
}

/* ---------------------------------------------------------------------------
   Reprise d'un projet Qlicklab : le client saisit le code d'accès qu'il
   utilisait auparavant, et son compte est rattaché au projet repris.
   --------------------------------------------------------------------------- */
function rejoindreProjet(code) {
  return sb.rpc('cre8_rejoindre_projet', { p_code: String(code || '').trim() })
    .then(verifier)
    .then(function (r) { return (r && r[0]) || null; });
}

/* ---------------------------------------------------------------------------
   Lecture de l'espace : tout ce dont la page a besoin, en une fois.
   --------------------------------------------------------------------------- */
function compteCourant(s) {
  return sb.from('cre8_comptes')
    .select('id,email,nom,initiales,role,telephone,societe,secteur,avatar_url')
    .eq('id', s.user.id)
    .maybeSingle()
    .then(function (r) {
      var m = s.user.user_metadata || {};
      return r.data || {
        id: s.user.id,
        email: s.user.email || '',
        nom: m.full_name || '',
        initiales: '',
        role: 'client',
        telephone: m.telephone || '',
        societe: m.societe || '',
        secteur: m.secteur || '',
        avatar_url: m.avatar_url || m.picture || ''
      };
    });
}

function chargerEspace() {
  return session().then(function (s) {
    if (!s) return null;
    return compteCourant(s).then(function (compte) {
      return sb.from('cre8_projets')
        .select('*')
        .eq('statut', 'actif')
        .order('maj_le', { ascending: false })
        .limit(1)
        .then(verifier)
        .then(function (projets) {
          var projet = (projets || [])[0] || null;
          if (!projet) return { compte: compte, projet: null };

          var id = projet.id;
          return Promise.all([
            sb.from('cre8_options').select('*').eq('actif', true).order('rang'),
            sb.from('cre8_projet_options').select('*').eq('projet_id', id).order('cree_le'),
            sb.from('cre8_offres').select('*').eq('projet_id', id).order('cree_le', { ascending: false }),
            sb.from('cre8_messages').select('*').eq('projet_id', id).order('cree_le'),
            sb.from('cre8_actions').select('*').eq('projet_id', id).order('cree_le', { ascending: false }).limit(12),
            sb.from('cre8_factures').select('*').eq('projet_id', id).order('cree_le'),
            sb.from('cre8_taches').select('*').eq('projet_id', id).order('rang')
          ]).then(function (t) {
            return {
              compte:        compte,
              projet:        projet,
              options:       verifier(t[0]) || [],
              projetOptions: verifier(t[1]) || [],
              offres:        verifier(t[2]) || [],
              messages:      verifier(t[3]) || [],
              actions:       verifier(t[4]) || [],
              factures:      verifier(t[5]) || [],
              taches:        verifier(t[6]) || []
            };
          });
        });
    });
  });
}

/* ---------------------------------------------------------------------------
   Écritures
   --------------------------------------------------------------------------- */
function ajouterAuPanier(projetId, opt) {
  return sb.from('cre8_projet_options').insert({
    projet_id: projetId,
    option_id: opt.catalogue ? opt.id : null,
    offre_id:  opt.catalogue ? null : (opt.offreId || null),
    nom:  opt.nom,
    prix: opt.prix,
    jours: opt.jours || 0,
    statut: 'panier'
  }).select().then(verifier).then(function (r) { return (r && r[0]) || null; });
}

function retirerDuPanier(ligneId) {
  return sb.from('cre8_projet_options').delete().eq('id', ligneId).then(verifier);
}

function repondreOffre(offreId, etat) {
  return sb.from('cre8_offres')
    .update({ etat: etat, repondu_le: new Date().toISOString() })
    .eq('id', offreId)
    .select()
    .then(verifier)
    .then(function (r) { return (r && r[0]) || null; });
}

function creerOffre(projetId, compte, o) {
  return sb.from('cre8_offres').insert({
    projet_id:  projetId,
    auteur_id:  compte.id,
    auteur_nom: compte.nom || compte.email,
    titre:      o.titre,
    texte:      o.texte || '',
    prix:       o.prix || 0,
    prix_avant: o.prixAvant || null,
    jours:      o.jours || 0,
    valide_jusqu: o.valide || null,
    etat:       'ouverte'
  }).select().then(verifier).then(function (r) { return (r && r[0]) || null; });
}

function envoyerMessage(projetId, compte, m) {
  return sb.from('cre8_messages').insert({
    projet_id:  projetId,
    auteur_id:  compte.id,
    auteur_nom: compte.nom || compte.email,
    role:       m.role || 'client',
    type:       m.type || 'message',
    texte:      m.texte || '',
    offre_id:   m.offreId || null
  }).select().then(verifier).then(function (r) { return (r && r[0]) || null; });
}

function marquerLu(projetId) {
  return sb.from('cre8_messages')
    .update({ lu_le: new Date().toISOString() })
    .eq('projet_id', projetId)
    .is('lu_le', null)
    .neq('role', 'client')
    .then(function () { return true; })
    .catch(function () { return false; });   // le client n'a pas toujours le droit d'écrire ici
}

function ajouterAction(projetId, texte) {
  return sb.from('cre8_actions').insert({
    projet_id: projetId, kind: 'jalon', texte: texte
  }).select().then(verifier).then(function (r) { return (r && r[0]) || null; });
}

/* ---------------------------------------------------------------------------
   Temps réel : le fil de discussion se met à jour sans recharger la page.
   --------------------------------------------------------------------------- */
function ecouter(projetId, quand) {
  var canal = sb.channel('cre8-projet-' + projetId);
  ['cre8_messages', 'cre8_offres', 'cre8_projet_options', 'cre8_actions'].forEach(function (t) {
    canal.on('postgres_changes',
      { event: '*', schema: 'public', table: t, filter: 'projet_id=eq.' + projetId },
      function (charge) { quand(t, charge); });
  });
  canal.subscribe();
  return function () { sb.removeChannel(canal); };
}

w.CRE8 = {
  sb: sb,
  conf: CONF,
  base: base,
  messageErreur: messageErreur,
  session: session,
  connexion: connexion,
  inscription: inscription,
  inscriptionOuverte: inscriptionOuverte,
  google: google,
  motDePasseOublie: motDePasseOublie,
  deconnexion: deconnexion,
  profil: profil,
  memorise: memorise,
  memoriser: memoriser,
  rejoindreProjet: rejoindreProjet,
  chargerEspace: chargerEspace,
  ajouterAuPanier: ajouterAuPanier,
  retirerDuPanier: retirerDuPanier,
  repondreOffre: repondreOffre,
  creerOffre: creerOffre,
  envoyerMessage: envoyerMessage,
  marquerLu: marquerLu,
  ajouterAction: ajouterAction,
  ecouter: ecouter
};

})(window);
