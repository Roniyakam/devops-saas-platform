# ADR 001 — Environnement de déploiement : Scaleway dès le départ

**Date** : Juin 2026  
**Statut** : Accepté  
**Décideurs** : Roni (DevOps Engineer)

## Contexte

Deux options étaient envisagées pour l'environnement de développement :
1. **VirtualBox local** : gratuit, fonctionne offline, mais nécessite une migration vers Scaleway en semaine 4
2. **Scaleway dès le départ** : cloud réel, coût faible (arrêt des instances entre sessions), pas de migration

## Décision

Déploiement sur **Scaleway cloud dès la semaine 1**.

## Justification

- **Évite une migration risquée en semaine 4** : migrer à la dernière semaine avant l'entretien introduirait du risque sans valeur ajoutée
- **Démo plus forte** : pouvoir dire "déployé sur un vrai cloud Scaleway" est plus percutant qu'un environnement VirtualBox
- **Élimine les problèmes de virtualisation** : nested virtualization, réseau, bridge — ces problèmes n'existent pas sur une vraie VM cloud
- **Coût maîtrisé** : instances arrêtées entre les sessions → ~22-26€/semaine sur 4 semaines

## Conséquences

- Coût d'environ 90€/mois en tarif plein, ramené à ~100€ total sur 4 semaines avec la stratégie stop/start
- Nécessite une connexion internet pour travailler
- L'inventaire Ansible contient des IPs Scaleway réelles (voir `hosts.ini`)
