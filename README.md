# Pathfinder — EECS 449 Group 16

A Simplify-inspired job discovery and application assistant built on the existing Jac + Jooble project.

## What changed

The original repository was a CLI that searched Jooble. This version keeps that live job source but turns the project into a full-stack Jac web app with:

- **Persistent candidate profile** — contact info, education, links, skills, work authorization, sponsorship, location and remote preferences.
- **Autofill workspace** — opening a job preloads the saved profile so users do not repeatedly re-enter the same application information.
- **Recommended jobs** — jobs receive a match score based on target role, skills, preferred locations, and remote preference.
- **Search** — users can still search Jooble directly.
- **Application tracker** — records jobs as Applied and lets users move them to Interview, Offer, Rejected, or Withdrawn.
- **No-key demo mode** — curated demo jobs appear if `JOOBLE_API_KEY` is not configured, so the project is always demoable.
- **Responsive UI** — desktop and mobile layouts.

## Important autofill limitation

A normal web app cannot silently inject data into and submit arbitrary third-party Workday, Greenhouse, Lever, etc. pages. Those pages are on different origins and may include authentication or CAPTCHA. Pathfinder therefore provides the saved-profile/autofill experience inside the app, opens the employer application in a new tab, and tracks the user's submission.

A true Simplify-style cross-site autofill would be the next feature: a browser extension/content script that reads the Pathfinder profile and maps fields on supported ATS pages.

## Run locally

This project is pinned to Jac `0.37.11`, matching the original repository.

```bash
cp .env.example .env
# Optional: put a real Jooble key in .env
jac install
jac run --dev main.jac
```

Then open `http://localhost:8000`.

If your class environment already installed dependencies for the repo, you may only need:

```bash
jac run --dev main.jac
```

## Jooble

Set this in `.env` for live jobs:

```bash
JOOBLE_API_KEY=your_real_key
```

If the key is absent or the request fails, Pathfinder falls back to demo jobs rather than breaking the UI.

## Suggested next upgrades

1. Add Jac built-in authentication and change the profile/application endpoints to protected per-user storage.
2. Add a browser extension for real ATS autofill (Greenhouse and Lever first).
3. Upload and parse resumes to populate the profile automatically.
4. Add LLM-assisted cover-letter and short-answer drafting.
5. Save/bookmark jobs separately from applications.
6. Add filters for internship/full-time, salary, remote, date posted, and visa sponsorship.
