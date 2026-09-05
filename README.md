# Hintvite Growth Engine — V1

Cette V1 transforme le questionnaire Hintvite en première brique d'une infrastructure commerciale centralisée :

- questionnaire public → Supabase
- espace admin protégé → réponses + prospects + marques
- CRM de prospection
- scoring IA des prospects via Supabase Edge Function + OpenAI
- tables prêtes pour campagnes, messages, activités et tâches IA
- template n8n pour déclencher le scoring

## Architecture

```text
Architecte / designer
        ↓
public/questionnaire.html
        ↓
Supabase / questionnaire_responses
        ↓
admin.html ← Auth Supabase
        ↓
prospects / brands / activities / messages
        ↓
Edge Function score-prospect
        ↓
OpenAI Responses API
        ↓
score + résumé + angle commercial
```

## 1. Créer le projet Supabase

1. Ouvre https://supabase.com/
2. Crée un projet.
3. Dans **SQL Editor**, colle `supabase/schema.sql` puis exécute-le.
4. Dans **Authentication → Users**, crée ton utilisateur administrateur avec email + mot de passe.
5. Copie l'UUID de cet utilisateur.
6. Dans SQL Editor, exécute :

```sql
insert into public.app_admins(user_id, role)
values ('TON-UUID-ICI', 'admin');
```

## 2. Récupérer les clés

Dans Supabase → **Connect** / **API Keys**, récupère le Project URL et la Publishable key. Supabase recommande d'utiliser la clé publishable côté navigateur et de protéger toutes les tables par RLS. Ne mets jamais la secret key/service role dans le navigateur. Voir la documentation officielle : https://supabase.com/docs/guides/getting-started/api-keys

Modifie `public/config.js` :

```js
window.HINTVITE_CONFIG = {
  SUPABASE_URL: 'https://xxxx.supabase.co',
  SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_xxxx',
  MODE: 'public'
};
```

## 3. Déployer le questionnaire

Le dossier `public/` est un site statique.

Tu peux le publier sur Vercel, Netlify, Cloudflare Pages ou un hébergement web classique.

Le lien à donner aux architectes sera :

`https://TON-DOMAINE/` (ou `/questionnaire.html`)

Le questionnaire original est conservé sous `public/questionnaire-original.html`.

## 4. Déployer l'admin

L'espace administrateur est :

`https://TON-DOMAINE/admin.html`

Il exige une connexion Supabase Auth et les policies RLS vérifient que l'utilisateur est dans `app_admins`.

## 5. Activer le scoring IA

Installe le Supabase CLI puis connecte le projet. Depuis le dossier du projet :

```bash
supabase login
supabase link --project-ref TON_PROJECT_REF
supabase functions deploy score-prospect
supabase secrets set OPENAI_API_KEY="TON_OPENAI_KEY" OPENAI_MODEL="gpt-5"
```

La clé OpenAI doit rester côté serveur. OpenAI indique explicitement de ne jamais exposer une clé API dans du code client. La V1 utilise l'endpoint Responses API côté Edge Function.

## 6. Tester le scoring

Crée un prospect dans `prospects`, puis appelle l'Edge Function avec un utilisateur authentifié :

```json
{"prospect_id":"UUID_DU_PROSPECT"}
```

Le résultat produit notamment :

- score 0–100
- priorité
- raison
- résumé
- angle commercial

## 7. n8n

`n8n-score-prospect.json` est un template de workflow :

Webhook → Edge Function → retour du score.

Pour la V2, on branchera dessus :

1. collecte/enrichissement des cabinets
2. déduplication
3. scoring
4. génération du premier email
5. validation humaine
6. envoi
7. suivi des réponses
8. relances
9. création automatique de rendez-vous

## Sécurité

- `public/config.js` ne doit contenir que l'URL Supabase et la Publishable key.
- Jamais de `service_role` / secret key dans le navigateur.
- La lecture des réponses est réservée aux admins via RLS.
- La clé OpenAI reste uniquement dans l'Edge Function / serveur.
- Avant une prospection massive, configure les règles de conformité, désinscription et gestion des données personnelles adaptées à ton usage.

## Ce qui est déjà prêt

Le questionnaire existant est conservé et son enregistrement public est branché sur `questionnaire_responses`. Les réponses structurées sont stockées dans `payload`, ce qui permet de conserver les champs spécifiques du questionnaire sans les perdre.

Le modèle CRM est également prêt pour la suite : prospects, activités, marques, campagnes, messages et tâches IA.
