"""Pathfinder - a Simplify-inspired job discovery and application assistant.

The app keeps the original Jooble integration, adds a persistent candidate
profile, job matching, a saved-info autofill workflow, and an application
tracker. When JOOBLE_API_KEY is absent the UI falls back to demo jobs so the
project is still fully demonstrable.
"""

import datetime;
import json;
import os;
import re;
import urllib.error;
import urllib.request;

import "./styles.css";


obj Job {
    has id: str,
        title: str,
        company: str,
        location: str,
        salary: str = "",
        link: str = "",
        description: str = "",
        source: str = "Jooble",
        match_score: int = 50;
}

node CandidateProfile {
    has full_name: str = "",
        email: str = "",
        phone: str = "",
        location: str = "",
        school: str = "",
        degree: str = "",
        graduation_year: str = "",
        linkedin: str = "",
        github: str = "",
        portfolio: str = "",
        desired_role: str = "Software Engineer Intern",
        desired_locations: str = "Remote, New York, Ann Arbor",
        skills: str = "Python, SQL, JavaScript, React",
        work_authorized: bool = True,
        needs_sponsorship: bool = False,
        remote_ok: bool = True,
        relocate_ok: bool = True;
}

node Application {
    has job_id: str,
        title: str,
        company: str,
        location: str,
        link: str = "",
        status: str = "Applied",
        applied_at: str = "",
        note: str = "";
}


def load_env_file(filepath: str = ".env") {
    if os.path.exists(filepath) {
        try {
            with open(filepath, "r") as f {
                for raw_line in f {
                    line = raw_line.strip();
                    if line and not line.startswith("#") and "=" in line {
                        (k, v) = line.split("=", 1);
                        key_name = k.strip();
                        val = v.strip().strip("'").strip("\"");
                        if key_name and key_name not in os.environ {
                            os.environ[key_name] = val;
                        }
                    }
                }
            }
        } except Exception {
            # Ignore optional .env read errors.
        }
    }
}


def clean_text(value: str) -> str {
    cleaned = re.sub(r"<[^>]+>", " ", value or "");
    cleaned = re.sub(r"\s+", " ", cleaned);
    return cleaned.strip();
}


def demo_jobs -> list[Job] {
    return [
        Job(
            id="demo-1",
            title="Software Engineer Intern",
            company="Northstar Labs",
            location="New York, NY",
            salary="$38 - $48/hr",
            link="https://example.com/jobs/software-engineer-intern",
            description="Build production web features with Python, TypeScript, React, SQL, REST APIs, and cloud infrastructure. Internship with strong mentorship.",
            source="Demo"
        ),
        Job(
            id="demo-2",
            title="Data Science Intern",
            company="Arbor Analytics",
            location="Ann Arbor, MI",
            salary="$32 - $42/hr",
            link="https://example.com/jobs/data-science-intern",
            description="Use Python, pandas, SQL, statistics, machine learning, experimentation, and visualization to solve product analytics problems.",
            source="Demo"
        ),
        Job(
            id="demo-3",
            title="Machine Learning Engineer Intern",
            company="VectorWorks AI",
            location="Remote",
            salary="$40 - $52/hr",
            link="https://example.com/jobs/ml-engineer-intern",
            description="Prototype machine learning systems using Python, PyTorch, embeddings, model evaluation, APIs, and data pipelines.",
            source="Demo"
        ),
        Job(
            id="demo-4",
            title="Backend Engineer Intern",
            company="Foundry Systems",
            location="Jersey City, NJ",
            salary="$36 - $46/hr",
            link="https://example.com/jobs/backend-engineer-intern",
            description="Develop reliable backend services and data workflows using Python, SQL, cloud systems, testing, and distributed data tools.",
            source="Demo"
        ),
        Job(
            id="demo-5",
            title="Full Stack Developer Intern",
            company="CampusCloud",
            location="Remote",
            salary="$30 - $40/hr",
            link="https://example.com/jobs/full-stack-intern",
            description="Ship customer-facing features with React, TypeScript, Node.js, APIs, databases, and modern deployment workflows.",
            source="Demo"
        ),
        Job(
            id="demo-6",
            title="Data Engineer Intern",
            company="Ledger Data",
            location="New York, NY",
            salary="$35 - $45/hr",
            link="https://example.com/jobs/data-engineer-intern",
            description="Build ingestion pipelines, lakehouse tables, SQL transformations, data quality checks, and cloud workflows.",
            source="Demo"
        ),
        Job(
            id="demo-7",
            title="Product Analytics Intern",
            company="Signal Product Co.",
            location="Boston, MA",
            salary="$31 - $39/hr",
            link="https://example.com/jobs/product-analytics-intern",
            description="Analyze product behavior with SQL, Python, statistics, experiments, dashboards, and stakeholder communication.",
            source="Demo"
        ),
        Job(
            id="demo-8",
            title="Cloud Software Engineering Intern",
            company="BluePeak Infrastructure",
            location="Remote",
            salary="$37 - $47/hr",
            link="https://example.com/jobs/cloud-software-intern",
            description="Work on cloud services, APIs, Python automation, Linux, testing, and data platform reliability.",
            source="Demo"
        )
    ];
}


def fetch_jobs(n: int, search: str, location: str = "", api_key: str | None = None) -> list[Job] {
    if n <= 0 {
        return [];
    }

    load_env_file();
    key = api_key or os.environ.get("JOOBLE_API_KEY", "");
    if not key or key == "your_jooble_api_key_here" {
        return demo_jobs()[:n];
    }

    url = f"https://jooble.org/api/{key}";
    request_body: dict[str, any] = {"keywords": search, "ResultOnPage": n};
    if location.strip() {
        request_body["location"] = location.strip();
    }
    body = json.dumps(request_body).encode("utf-8");
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}
    );

    try {
        with urllib.request.urlopen(req) as resp {
            payload = json.loads(resp.read().decode("utf-8"));
        }
    } except Exception {
        return demo_jobs()[:n];
    }

    raw_jobs = payload.get("jobs", []) if isinstance(payload, dict) else [];
    jobs: list[Job] = [];
    for raw in raw_jobs[:n] {
        raw_link = str(raw.get("link", ""));
        raw_id = str(raw.get("id", raw_link));
        description = clean_text(str(raw.get("snippet", raw.get("description", ""))));
        jobs.append(Job(
            id=raw_id,
            title=str(raw.get("title", "Untitled role")),
            company=str(raw.get("company", "Unknown company")),
            location=str(raw.get("location", "Location not listed")),
            salary=str(raw.get("salary", "")),
            link=raw_link,
            description=description,
            source=str(raw.get("source", "Jooble"))
        ));
    }

    return jobs if jobs else demo_jobs()[:n];
}


def calculate_match(job: Job, profile: CandidateProfile | None) -> int {
    if profile is None {
        return 60;
    }

    score = 45;
    haystack = f"{job.title} {job.company} {job.location} {job.description}".lower();
    desired = profile.desired_role.strip().lower();

    if desired and desired in haystack {
        score += 25;
    } else {
        for word in desired.split() {
            if len(word) > 3 and word in haystack {
                score += 4;
            }
        }
    }

    for raw_skill in profile.skills.split(",") {
        skill = raw_skill.strip().lower();
        if skill and skill in haystack {
            score += 5;
        }
    }

    if profile.remote_ok and "remote" in job.location.lower() {
        score += 8;
    }

    for raw_location in profile.desired_locations.split(",") {
        desired_location = raw_location.strip().lower();
        if desired_location and desired_location in job.location.lower() {
            score += 7;
        }
    }

    if score > 99 {
        score = 99;
    }
    if score < 1 {
        score = 1;
    }
    return score;
}


def rank_jobs(jobs: list[Job], profile: CandidateProfile | None) -> list[Job] {
    ranked: list[Job] = [];
    for job in jobs {
        scored = Job(
            id=job.id,
            title=job.title,
            company=job.company,
            location=job.location,
            salary=job.salary,
            link=job.link,
            description=job.description,
            source=job.source,
            match_score=calculate_match(job, profile)
        );
        inserted = False;
        for i in range(len(ranked)) {
            if scored.match_score > ranked[i].match_score {
                ranked.insert(i, scored);
                inserted = True;
                break;
            }
        }
        if not inserted {
            ranked.append(scored);
        }
    }
    return ranked;
}


def:pub get_profile -> CandidateProfile | None {
    profiles = [root-->][?:CandidateProfile];
    return profiles[0] if profiles else None;
}


def:pub save_profile(
    full_name: str,
    email: str,
    phone: str,
    location: str,
    school: str,
    degree: str,
    graduation_year: str,
    linkedin: str,
    github: str,
    portfolio: str,
    desired_role: str,
    desired_locations: str,
    skills: str,
    work_authorized: bool,
    needs_sponsorship: bool,
    remote_ok: bool,
    relocate_ok: bool
) -> CandidateProfile {
    profiles = [root-->][?:CandidateProfile];
    if profiles {
        profile = profiles[0];
        profile.full_name = full_name;
        profile.email = email;
        profile.phone = phone;
        profile.location = location;
        profile.school = school;
        profile.degree = degree;
        profile.graduation_year = graduation_year;
        profile.linkedin = linkedin;
        profile.github = github;
        profile.portfolio = portfolio;
        profile.desired_role = desired_role;
        profile.desired_locations = desired_locations;
        profile.skills = skills;
        profile.work_authorized = work_authorized;
        profile.needs_sponsorship = needs_sponsorship;
        profile.remote_ok = remote_ok;
        profile.relocate_ok = relocate_ok;
        return profile;
    }

    profile = root ++> CandidateProfile(
        full_name=full_name,
        email=email,
        phone=phone,
        location=location,
        school=school,
        degree=degree,
        graduation_year=graduation_year,
        linkedin=linkedin,
        github=github,
        portfolio=portfolio,
        desired_role=desired_role,
        desired_locations=desired_locations,
        skills=skills,
        work_authorized=work_authorized,
        needs_sponsorship=needs_sponsorship,
        remote_ok=remote_ok,
        relocate_ok=relocate_ok
    );
    return profile;
}


def:pub recommend_jobs(limit: int = 18) -> list[Job] {
    profile = get_profile();
    query = "software engineer intern";
    location = "";
    if profile is not None {
        if profile.desired_role.strip() {
            query = profile.desired_role.strip();
        }
        if profile.skills.strip() {
            first_skills = ", ".join([s.strip() for s in profile.skills.split(",")[:3] if s.strip()]);
            if first_skills {
                query = f"{query} {first_skills}";
            }
        }
        if profile.desired_locations.strip() {
            location = profile.desired_locations.split(",")[0].strip();
        }
    }
    return rank_jobs(fetch_jobs(limit, query, location), profile);
}


def:pub search_jobs(search: str, limit: int = 24) -> list[Job] {
    profile = get_profile();
    query = search.strip() if search.strip() else "software engineer intern";
    location = profile.location if profile is not None else "";
    return rank_jobs(fetch_jobs(limit, query, location), profile);
}


def:pub record_application(
    job_id: str,
    title: str,
    company: str,
    location: str,
    link: str,
    note: str = ""
) -> Application {
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M");
    for app in [root-->][?:Application] {
        if app.job_id == job_id {
            app.status = "Applied";
            app.applied_at = now;
            app.note = note;
            return app;
        }
    }

    app = root ++> Application(
        job_id=job_id,
        title=title,
        company=company,
        location=location,
        link=link,
        status="Applied",
        applied_at=now,
        note=note
    );
    return app;
}


def:pub list_applications -> list[Application] {
    apps = [root-->][?:Application];
    apps.reverse();
    return apps;
}


def:pub update_application_status(id: str, status: str) -> Application | None {
    for app in [root-->][?:Application] {
        if jid(app) == id {
            app.status = status;
            return app;
        }
    }
    return None;
}


def:pub app -> JsxElement {
    has active_tab: str = "jobs",
        loading_jobs: bool = True,
        saving_profile: bool = False,
        profile_message: str = "",
        search_term: str = "",
        jobs: list[Job] = [],
        applications: list[Application] = [],
        full_name: str = "",
        email: str = "",
        phone: str = "",
        profile_location: str = "",
        school: str = "",
        degree: str = "",
        graduation_year: str = "",
        linkedin: str = "",
        github: str = "",
        portfolio: str = "",
        desired_role: str = "Software Engineer Intern",
        desired_locations: str = "Remote, New York, Ann Arbor",
        skills: str = "Python, SQL, JavaScript, React",
        work_authorized: bool = True,
        needs_sponsorship: bool = False,
        remote_ok: bool = True,
        relocate_ok: bool = True,
        selected_id: str = "",
        selected_title: str = "",
        selected_company: str = "",
        selected_location: str = "",
        selected_salary: str = "",
        selected_link: str = "",
        application_note: str = "",
        application_message: str = "";

    async can with entry {
        existing = await get_profile();
        if existing is not None {
            full_name = existing.full_name;
            email = existing.email;
            phone = existing.phone;
            profile_location = existing.location;
            school = existing.school;
            degree = existing.degree;
            graduation_year = existing.graduation_year;
            linkedin = existing.linkedin;
            github = existing.github;
            portfolio = existing.portfolio;
            desired_role = existing.desired_role;
            desired_locations = existing.desired_locations;
            skills = existing.skills;
            work_authorized = existing.work_authorized;
            needs_sponsorship = existing.needs_sponsorship;
            remote_ok = existing.remote_ok;
            relocate_ok = existing.relocate_ok;
        }
        jobs = await recommend_jobs(18);
        applications = await list_applications();
        loading_jobs = False;
    }

    async def refresh_jobs {
        loading_jobs = True;
        jobs = await recommend_jobs(18);
        loading_jobs = False;
    }

    async def run_search(e: FormEvent) {
        e.preventDefault();
        loading_jobs = True;
        jobs = await search_jobs(search_term, 24);
        loading_jobs = False;
    }

    async def save_candidate(e: FormEvent) {
        e.preventDefault();
        saving_profile = True;
        profile_message = "";
        await save_profile(
            full_name,
            email,
            phone,
            profile_location,
            school,
            degree,
            graduation_year,
            linkedin,
            github,
            portfolio,
            desired_role,
            desired_locations,
            skills,
            work_authorized,
            needs_sponsorship,
            remote_ok,
            relocate_ok
        );
        saving_profile = False;
        profile_message = "Profile saved. Recommendations were refreshed.";
        jobs = await recommend_jobs(18);
    }

    def start_application(job: Job) {
        selected_id = job.id;
        selected_title = job.title;
        selected_company = job.company;
        selected_location = job.location;
        selected_salary = job.salary;
        selected_link = job.link;
        application_note = "";
        application_message = "";
    }

    def close_application {
        selected_id = "";
    }

    async def mark_applied {
        if not selected_id {
            return;
        }
        await record_application(
            selected_id,
            selected_title,
            selected_company,
            selected_location,
            selected_link,
            application_note
        );
        applications = await list_applications();
        application_message = "Saved as applied.";
    }

    async def change_status(id: str, status: str) {
        updated = await update_application_status(id, status);
        if updated is not None {
            applications = [updated if jid(a) == id else a for a in applications];
        }
    }

    return
        <div class="app-shell">
            <header class="topbar">
                <div class="brand-row">
                    <div class="logo-mark">P</div>
                    <div>
                        <div class="brand">Pathfinder</div>
                        <div class="brand-subtitle">Find better-fit jobs. Apply faster.</div>
                    </div>
                </div>
                <nav class="nav-tabs">
                    <button class={"nav-tab " + ("active" if active_tab == "jobs" else "")} onClick={lambda { active_tab = "jobs"; }}>Jobs</button>
                    <button class={"nav-tab " + ("active" if active_tab == "profile" else "")} onClick={lambda { active_tab = "profile"; }}>Autofill Profile</button>
                    <button class={"nav-tab " + ("active" if active_tab == "applications" else "")} onClick={lambda { active_tab = "applications"; }}>Applications <span class="count-pill">{len(applications)}</span></button>
                </nav>
            </header>

            <main class="main-content">
                <section class={"page-section " + ("hidden" if active_tab != "jobs" else "")}>
                    <div class="hero-card">
                        <div>
                            <div class="eyebrow">PERSONALIZED JOB DISCOVERY</div>
                            <h1>Jobs matched to your profile</h1>
                            <p>Save your information once, then use it across every application. Match scores favor your role, skills, locations, and remote preferences.</p>
                        </div>
                        <button class="btn secondary" onClick={lambda { active_tab = "profile"; }}>Edit profile</button>
                    </div>

                    <form class="search-bar" onSubmit={run_search}>
                        <span class="search-icon">⌕</span>
                        <input value={search_term} onChange={lambda (e: ChangeEvent) { search_term = e.target.value; }} placeholder="Search jobs, e.g. data science intern" />
                        <button class="btn primary" type="submit">Search</button>
                        <button class="btn ghost" type="button" onClick={refresh_jobs}>Recommended</button>
                    </form>

                    <div class="section-heading">
                        <div>
                            <h2>{("Recommended jobs" if not search_term else "Job results")}</h2>
                            <p>{len(jobs)} roles ranked for you</p>
                        </div>
                    </div>

                    {(
                        <div class="loading-state">Finding the best matches…</div>
                    ) if loading_jobs else (
                        <div class="job-grid">
                            {[
                                <article class="job-card" key={job.id}>
                                    <div class="job-card-top">
                                        <div class="company-avatar">{job.company[:1]}</div>
                                        <div class="match-badge">{job.match_score}% match</div>
                                    </div>
                                    <h3>{job.title}</h3>
                                    <div class="company-name">{job.company}</div>
                                    <div class="job-meta">
                                        <span>⌖ {job.location}</span>
                                        {(<span>• {job.salary}</span>) if job.salary else (<span></span>)}
                                    </div>
                                    <p class="job-description">{job.description[:220]}</p>
                                    <div class="skill-row">
                                        <span class="source-chip">{job.source}</span>
                                        <span class="autofill-chip">Autofill ready</span>
                                    </div>
                                    <div class="job-actions">
                                        <button class="btn primary grow" onClick={lambda { start_application(job); }}>Quick apply</button>
                                        <a class="btn ghost" href={job.link} target="_blank" rel="noreferrer">View ↗</a>
                                    </div>
                                </article>
                                for job in jobs
                            ]}
                        </div>
                    )}
                </section>

                <section class={"page-section " + ("hidden" if active_tab != "profile" else "")}>
                    <div class="page-title-row">
                        <div>
                            <div class="eyebrow">AUTOFILL PROFILE</div>
                            <h1>Your application information</h1>
                            <p>Enter this once. Pathfinder uses it to rank jobs and prefill your application workspace.</p>
                        </div>
                    </div>

                    <form class="profile-layout" onSubmit={save_candidate}>
                        <div class="form-card">
                            <h2>Contact</h2>
                            <div class="form-grid two-col">
                                <label>Full name<input value={full_name} onChange={lambda (e: ChangeEvent) { full_name = e.target.value; }} placeholder="Jane Doe" /></label>
                                <label>Email<input type="email" value={email} onChange={lambda (e: ChangeEvent) { email = e.target.value; }} placeholder="jane@example.com" /></label>
                                <label>Phone<input value={phone} onChange={lambda (e: ChangeEvent) { phone = e.target.value; }} placeholder="(555) 555-5555" /></label>
                                <label>Location<input value={profile_location} onChange={lambda (e: ChangeEvent) { profile_location = e.target.value; }} placeholder="Ann Arbor, MI" /></label>
                            </div>
                        </div>

                        <div class="form-card">
                            <h2>Education & links</h2>
                            <div class="form-grid two-col">
                                <label>School<input value={school} onChange={lambda (e: ChangeEvent) { school = e.target.value; }} placeholder="University" /></label>
                                <label>Degree<input value={degree} onChange={lambda (e: ChangeEvent) { degree = e.target.value; }} placeholder="B.S. Computer Science" /></label>
                                <label>Graduation year<input value={graduation_year} onChange={lambda (e: ChangeEvent) { graduation_year = e.target.value; }} placeholder="2027" /></label>
                                <label>LinkedIn<input value={linkedin} onChange={lambda (e: ChangeEvent) { linkedin = e.target.value; }} placeholder="linkedin.com/in/..." /></label>
                                <label>GitHub<input value={github} onChange={lambda (e: ChangeEvent) { github = e.target.value; }} placeholder="github.com/..." /></label>
                                <label>Portfolio<input value={portfolio} onChange={lambda (e: ChangeEvent) { portfolio = e.target.value; }} placeholder="your-site.com" /></label>
                            </div>
                        </div>

                        <div class="form-card">
                            <h2>Job preferences</h2>
                            <div class="form-grid">
                                <label>Target role<input value={desired_role} onChange={lambda (e: ChangeEvent) { desired_role = e.target.value; }} placeholder="Software Engineer Intern" /></label>
                                <label>Preferred locations<input value={desired_locations} onChange={lambda (e: ChangeEvent) { desired_locations = e.target.value; }} placeholder="Remote, New York, Ann Arbor" /></label>
                                <label>Skills<textarea value={skills} onChange={lambda (e: ChangeEvent) { skills = e.target.value; }} placeholder="Python, SQL, React, machine learning"></textarea></label>
                            </div>
                            <div class="checkbox-grid">
                                <label class="check-row"><input type="checkbox" checked={work_authorized} onChange={lambda (e: ChangeEvent) { work_authorized = e.target.checked; }} /> Authorized to work in the U.S.</label>
                                <label class="check-row"><input type="checkbox" checked={needs_sponsorship} onChange={lambda (e: ChangeEvent) { needs_sponsorship = e.target.checked; }} /> Need visa sponsorship</label>
                                <label class="check-row"><input type="checkbox" checked={remote_ok} onChange={lambda (e: ChangeEvent) { remote_ok = e.target.checked; }} /> Open to remote roles</label>
                                <label class="check-row"><input type="checkbox" checked={relocate_ok} onChange={lambda (e: ChangeEvent) { relocate_ok = e.target.checked; }} /> Open to relocation</label>
                            </div>
                        </div>

                        <div class="sticky-save">
                            <span class="success-text">{profile_message}</span>
                            <button class="btn primary large" type="submit" disabled={saving_profile}>{("Saving…" if saving_profile else "Save profile & refresh matches")}</button>
                        </div>
                    </form>
                </section>

                <section class={"page-section " + ("hidden" if active_tab != "applications" else "")}>
                    <div class="page-title-row">
                        <div>
                            <div class="eyebrow">APPLICATION TRACKER</div>
                            <h1>Keep every application organized</h1>
                            <p>Track where you applied and move applications through your recruiting pipeline.</p>
                        </div>
                    </div>

                    {(
                        <div class="empty-card">
                            <div class="empty-icon">✓</div>
                            <h2>No applications yet</h2>
                            <p>Use Quick apply on a recommended job, open the employer page, then save it as applied.</p>
                            <button class="btn primary" onClick={lambda { active_tab = "jobs"; }}>Browse jobs</button>
                        </div>
                    ) if len(applications) == 0 else (
                        <div class="applications-list">
                            {[
                                <article class="application-row" key={jid(item)}>
                                    <div class="application-main">
                                        <div class="company-avatar small">{item.company[:1]}</div>
                                        <div>
                                            <h3>{item.title}</h3>
                                            <p>{item.company} • {item.location}</p>
                                            <span class="applied-date">Applied {item.applied_at}</span>
                                        </div>
                                    </div>
                                    <div class="application-actions">
                                        <select value={item.status} onChange={lambda (e: ChangeEvent) { change_status(jid(item), e.target.value); }}>
                                            <option value="Applied">Applied</option>
                                            <option value="Interview">Interview</option>
                                            <option value="Offer">Offer</option>
                                            <option value="Rejected">Rejected</option>
                                            <option value="Withdrawn">Withdrawn</option>
                                        </select>
                                        <a class="btn ghost" href={item.link} target="_blank" rel="noreferrer">Job ↗</a>
                                    </div>
                                </article>
                                for item in applications
                            ]}
                        </div>
                    )}
                </section>
            </main>

            <div class={"modal-backdrop " + ("hidden" if not selected_id else "")}>
                <div class="application-modal">
                    <div class="modal-header">
                        <div>
                            <div class="eyebrow">QUICK APPLY WORKSPACE</div>
                            <h2>{selected_title}</h2>
                            <p>{selected_company} • {selected_location} {("• " + selected_salary if selected_salary else "")}</p>
                        </div>
                        <button class="icon-button" onClick={close_application}>×</button>
                    </div>

                    <div class="notice-card">
                        <strong>Autofill ready.</strong> Your saved profile is prefilled below. Open the employer application in a new tab and use this panel as your single source of truth.
                    </div>

                    <div class="autofill-preview">
                        <div class="preview-field"><span>Name</span><strong>{full_name if full_name else "Not set"}</strong></div>
                        <div class="preview-field"><span>Email</span><strong>{email if email else "Not set"}</strong></div>
                        <div class="preview-field"><span>Phone</span><strong>{phone if phone else "Not set"}</strong></div>
                        <div class="preview-field"><span>Location</span><strong>{profile_location if profile_location else "Not set"}</strong></div>
                        <div class="preview-field"><span>School</span><strong>{school if school else "Not set"}</strong></div>
                        <div class="preview-field"><span>Degree</span><strong>{degree if degree else "Not set"}</strong></div>
                        <div class="preview-field"><span>LinkedIn</span><strong>{linkedin if linkedin else "Not set"}</strong></div>
                        <div class="preview-field"><span>GitHub</span><strong>{github if github else "Not set"}</strong></div>
                    </div>

                    <label class="modal-note">Application note<textarea value={application_note} onChange={lambda (e: ChangeEvent) { application_note = e.target.value; }} placeholder="Referral, recruiter name, custom cover letter note, etc."></textarea></label>
                    <div class="modal-footer">
                        <span class="success-text">{application_message}</span>
                        <div class="modal-buttons">
                            <a class="btn secondary" href={selected_link} target="_blank" rel="noreferrer">Open employer application ↗</a>
                            <button class="btn primary" onClick={mark_applied}>Mark as applied</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>;
}
