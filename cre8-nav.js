/* ===========================================================================
   cre8-nav.js — le bouton « Compte » de la barre de navigation.

   Déconnecté : un lien vers la page de connexion.
   Connecté   : la photo de profil (ou les initiales à défaut), qui mène à
                l'espace client.

   À charger après cre8-supabase.js, sur toutes les pages qui portent un
   élément #btnCompte.
   =========================================================================== */
(function (w, d) {
'use strict';

var bouton = d.getElementById('btnCompte');
if (!bouton) return;

/* ---------- habillage ---------- */
var CSS = '\
#btnCompte .cre8-ava{ display:inline-grid; place-items:center; overflow:hidden;\
  width:26px; height:26px; border-radius:50%; flex:0 0 auto;\
  background:#313EFF; color:#fff; font-weight:800; font-size:.72rem;\
  letter-spacing:.02em; line-height:1; }\
#btnCompte .cre8-ava img{ width:100%; height:100%; object-fit:cover; display:block; }\
#btnCompte[data-connecte="1"] svg{ display:none; }';

var style = d.createElement('style');
style.textContent = CSS;
d.head.appendChild(style);

function echapper(v) {
  return String(v == null ? '' : v)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function initiales(nom, email) {
  var p = String(nom || '').trim().split(/\s+/);
  var i = (p[0] ? p[0][0] : '') + (p[1] ? p[1][0] : '');
  return (i || (email || 'C')[0] || 'C').toUpperCase();
}

/* Le bouton d'origine est un <button> ; on le remplace par un <a> pour que
   le clic droit, le milieu et l'ouverture dans un onglet marchent comme
   partout ailleurs sur le site. */
function enLien(href, libelle, dedans, connecte) {
  var a = d.createElement('a');
  a.id = 'btnCompte';
  a.className = bouton.className;
  a.href = href;
  a.setAttribute('aria-label', libelle);
  if (connecte) a.dataset.connecte = '1';
  a.innerHTML = dedans;
  bouton.parentNode.replaceChild(a, bouton);
  bouton = a;
}

function deconnecte() {
  enLien('connexion.html', 'Se connecter',
    '<svg aria-hidden="true"><use href="#i-tete"/></svg><span class="txt">Compte</span>', false);
}

function connecte(p) {
  var nom = p.nom || p.email;
  var ini = p.initiales || initiales(p.nom, p.email);

  enLien('espace.html', 'Votre espace client — ' + nom,
    '<span class="cre8-ava" aria-hidden="true">' + echapper(ini) + '</span>' +
    '<span class="txt">' + echapper((nom || '').split(' ')[0] || 'Mon espace') + '</span>', true);

  /* La photo se pose par-dessus les initiales, et seulement si elle charge :
     une URL Google expirée laisse ainsi les initiales en place au lieu d'un
     carré vide. On construit l'élément plutôt que de l'écrire en HTML, pour
     ne pas avoir à glisser du code dans un attribut onerror. */
  if (!p.photo) return;
  var img = new Image();
  img.alt = '';
  img.referrerPolicy = 'no-referrer';
  img.onload = function () {
    var creux = bouton.querySelector('.cre8-ava');
    if (creux) { creux.textContent = ''; creux.appendChild(img); }
  };
  img.src = p.photo;
}

function peindre() {
  if (!w.CRE8 || w.CRE8.absent) { deconnecte(); return; }
  w.CRE8.profil()
    .then(function (p) { if (p) connecte(p); else deconnecte(); })
    .catch(deconnecte);
}

peindre();

/* connexion ou déconnexion dans un autre onglet : on se remet à jour */
if (w.CRE8 && !w.CRE8.absent && w.CRE8.sb && w.CRE8.sb.auth) {
  w.CRE8.sb.auth.onAuthStateChange(function (evt) {
    if (evt === 'SIGNED_IN' || evt === 'SIGNED_OUT' || evt === 'INITIAL_SESSION') peindre();
  });
}

})(window, document);
