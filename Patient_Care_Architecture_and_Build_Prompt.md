# Single-clinician patient care platform

Architecture and reusable build prompt — 25 September 2026

## Recommendation

Build a mobile-first progressive web app (PWA) for ongoing care between appointments. Use React, TypeScript and Vite on Cloudflare Pages; Supabase provides Postgres, authentication, row-level security, private storage, realtime updates and server functions. Keep one clinic and one clinician in the product. Avoid microservices and multi-clinic administration.

A zero-cost synthetic-data prototype is realistic. Do not promise indefinitely free, dependable clinical operations. Production decisions must include backups, recovery, authentication delivery, quotas, support, privacy and approved clinical scope. A paid database plan may be appropriate even with a free frontend.

Assumptions: one clinician; initially adult patients; approximately 100 active patients for design exercises, not a verified capacity claim; Asia/Colombo schedules; phone-first use; Sinhala, Tamil and English interface readiness. No diagram was available in the request. Confirm whether the clinician is a physiotherapist, psychologist, psychiatrist or another professional; these are different roles. Use “clinician” until qualifications and permitted services are established. Confirm whether “meditations” means meditation exercises or medication. Do not implement prescribing by assumption.

## Product scope

Patient navigation: Today, Progress, Messages, More. Today contains the next task, today's check-in and next appointment. More contains the care plan, education, account, language and help.

Clinician navigation: Overview, Patients, Messages, Schedule. Patient records contain a timeline, versioned care plan, shared progress, assessments and separately protected private notes.

| Capability | Initial release | Later |
|---|---|---|
| Patient access | Invite-only onboarding, consent, secure recovery | Delegated caregiver access after legal/clinical design |
| Care plans | Goals, instructions, recurrence, start/end dates, planned review | Reusable plan templates and richer approved media |
| Daily tasks | Done, partly done, skipped, need help; optional reason | Carefully scoped offline submissions |
| Check-ins | Clinician-selected mood, sleep, functioning or pain indicators | Additional condition-specific measures |
| Progress | Task participation, patient-reported trends, clinician reviews | Approved assessment trends |
| Communication | Persistent text chat, unread count, availability hours | Private attachments after scanning/security design |
| Follow-up | Appointment entries and clinician review queue | Booking integrations and optional reminders |
| Assessments | Framework and disabled unapproved instruments | Approved licensed instruments and translations |
| AI | Disabled; optional generic content drafting using no patient data | Reviewed clinician assistance under appropriate provider terms |

Avoid public patient profiles, rankings, streak penalties, a universal “mental health percentage”, automatic diagnosis, autonomous treatment changes, video appointments and billing in the first release.

## Architecture

1. Cloudflare serves the public application assets over HTTPS. It stores no patient content in the static deployment.
2. Supabase Auth identifies users. Roles and clinician-patient links are server-controlled.
3. Postgres is the source of truth. RLS protects every exposed patient table and private storage object. UI route guards are only a convenience.
4. Patient-owned routine writes may use the authenticated Supabase API under narrow policies. Privileged workflows use Edge Functions or tightly permissioned SQL functions: patient invitations, care-plan publication, assessment submission/scoring, exports and staff-only actions.
5. Realtime notifies authorized clients of committed changes. Clients invalidate/refetch relevant records. Reconnect always fetches canonical state; realtime events are not the durable record.
6. A scheduled database job creates task occurrences and a notification outbox. Dispatchers retry idempotently. In-app notices are the baseline; external push/email is optional and best effort.
7. A future AI adapter is server-side, feature-flagged and disconnected from patient data until provider, clinical and privacy requirements are satisfied.

### Suggested entities

- profiles: auth user, display name, preferred language; protected role metadata outside user-editable fields.
- patients and clinician_patient_links: minimal demographics, active relationship, enrollment status.
- consent_records: notice version, purpose, timestamp, withdrawal and representative where applicable.
- care_plans, care_plan_versions and goals: draft/published/archived states; immutable published versions.
- task_templates and task_occurrences: recurrence, local due date/time, plan version and cancellation reason.
- task_events: append-only status submissions/corrections, actor, timestamp and idempotency key.
- check_ins: configured measures, patient-entered values, effective date and submission time.
- appointments: scheduled/cancelled/completed, timezone and clinician.
- conversations, conversation_members and messages: participant authorization, durable sequence and read position.
- clinical_notes: clinician-only content in a separate protected table; patient summaries are separate records.
- assessment_definitions, assessment_versions, assessment_assignments, assessment_responses and assessment_scores: source, permission, age eligibility, language validation, recall period, deterministic scoring version and review status.
- review_items: reason, assigned clinician, open/acknowledged/resolved, timestamps and disposition.
- notification_outbox and notification_attempts: retries, delivery result and deduplication.
- audit_events: actor, action, object identifier and timestamp; no routine copies of sensitive text.

Use UUIDs, foreign keys, timestamps, status constraints and indexes on patient/date and conversation/message sequence. Use UTC timestamps plus Asia/Colombo calendar semantics. Unique task occurrence keys must prevent duplicate creation. Plan edits affect future instances; historical results retain the original plan version.

### Authorization rules

Patients can access only their own released plans, own submitted data, assessments assigned to them, appointments and conversations. They cannot change treatment instructions, scores, roles or other patients' identifiers. Clinicians access patients with an active authorized relationship. Private notes never appear in patient API results, realtime payloads, exports or search. Caregiver access is off by default; never assume that sharing a phone grants record access. No service-role secret in the browser. Privileged functions independently validate the caller and target patient.

### Daily scoring

Show “3 of 4 activities completed” first. If a percentage is needed, define it as completed eligible task occurrences / eligible task occurrences due that day × 100. A partial completion stays visibly partial rather than receiving invented clinical weight. Exclude cancelled/clinician-paused tasks; skipped tasks remain visible. If nothing is due, show “No tasks scheduled”, not 0%. Keep clinical screening scores, check-in values and participation separate. Missing reports mean unknown, not worsening illness or noncompliance. Do not infer causality from trends.

### Screening design

Call this “Wellbeing check-ins and screening”, not a disorder detector. WHO-5 and GAD-7 are candidates for clinician review; adult ASRS is a candidate only for appropriate adults and after permissions are resolved. This document does not grant instrument reuse rights or establish local validation. The PHQ Screeners site could not supply readable instrument documentation during research, so GAD-7 licensing/scoring must be verified before implementation.

Maintain an instrument registry with authoritative source, rights status, exact version, validated language/population, recall window, approved frequency, scoring algorithm, missing-answer rules and clinical owner. Do not invent or AI-translate validated questions, modify wording, apply adult instruments to children or repeat a multi-week screener daily. Unapproved instruments remain disabled. Score on the server using tested deterministic rules, never an LLM. Results explain uncertainty and offer clinician review; no “you have ADHD” output.

The clinician must approve escalation rules, operating hours, response expectations and local urgent-help information. Alerts go into an acknowledged review workflow; push delivery is never evidence that someone reviewed an alert. Chat is not an emergency service. If the clinic cannot staff a proposed alert workflow, do not launch that feature with emergency-response promises.

## UX specification

Use a warm white background, dark readable text and one calm teal or blue action color. Large 48px practical touch targets, generous spacing, 16–18px body text, visible focus, keyboard access and WCAG 2.2 AA as the implementation target. Use icons with words, not icons alone. Support reduced motion and do not communicate status with color alone. Avoid distracting animation and information-heavy dashboards.

One primary action per patient screen. Show date, duration, simple clinician-written instructions and a large completion control. Use progressive disclosure for details. Check-ins should take about one minute as a usability target. Keep navigation and help language consistent. Native speakers and the clinician review Sinhala/Tamil content; clinical translations require instrument-specific approval. Do not treat general UI translation as questionnaire validation.

Design loading, empty, error, expired-session, denied-permission, offline and retry states. Never claim a task or message is saved until acknowledged by the server. Cache the app shell only in the first release; no sensitive API responses in the service worker or persistent browser query cache. Explain offline status clearly. Purge in-memory patient data on logout; use no-store for sensitive responses and prevent shared-device history leakage where feasible.

Usability validation: ask representative low-digital-literacy users, in their preferred language, to sign in, find today's task, mark it complete and contact the clinician without coaching. Measure errors and completion time; simplify where users hesitate.

## Security, operations and launch conditions

- Clinician MFA, secure password recovery, rate limits and session revocation. No shared clinician logins.
- Invite-only enrollment; never use phone number or a short PIN alone as authentication. Confirm access for patients without personal email; do not invent fake email identities. SMS login requires provider and cost review.
- Custom SMTP is needed for real Supabase email flows; the built-in sender is restricted and not production-ready.
- No advertising pixels, session replay or patient content in analytics, URLs, logs, crash reports, email subjects or lock-screen previews.
- Private storage, short-lived authorized download URLs, size/type restrictions and later malware scanning before attachment rollout.
- Separate synthetic demo/staging and production environments. No real patient seed data in source control or development prompts.
- Document processor/subprocessor terms, hosting region, cross-border transfers, access requests, consent/lawful basis, record retention, incident response and deletion exceptions with appropriate local advice.
- Sri Lanka's PDPA has a 2025 amendment. Official web material still includes an older March 2025 commencement announcement; current commencement and applicable instruments were not conclusively established in this research. Do not assert a settled enforcement date or automatic compliance. Verify current Gazette/DPA position before launch.
- Maintain database AND private-object backups, separate protected backup storage and a tested restore procedure. Define agreed recovery time/data-loss objectives; a paid plan alone does not prove recoverability.
- Monitor quotas, errors, failed reminders and failed scheduled jobs. Maintain a clinic downtime/contact procedure. No uptime promises based on a free tier.

## Cost and platform decision

Cloudflare Pages static assets can be served free within platform terms and limits. Supabase Free lists 500 MB database, 1 GB file storage and possible pause after one week of inactivity; assess message/event growth and media volume rather than user-count allowance alone. Supabase Pro starts at USD 25/month on the pricing page, before applicable additions/taxes. Confirm current backup inclusions and exact project invoice before purchase.

Vercel is a valid paid alternative, but Hobby is restricted to personal, non-commercial use. If Vercel is a firm preference, use an appropriate commercial plan. React/Vite can still be hosted there; Next.js is optional rather than required for a private dashboard with no SEO need.

Domains, email delivery, SMS/WhatsApp, backup storage and operational support are not guaranteed free. Start with provider subdomains and in-app notifications for the demo. Gemini unpaid services must not receive confidential, sensitive or personal information. Use generic content drafting only, with clinician review, or keep AI entirely off. Do not assume removing a name makes patient text anonymous. AI access is also subject to provider age/use eligibility; the eligible clinic operator must manage any future integration.

## Delivery sequence

1. Confirm clinician scope, patient ages, languages, login access and diagram; approve screens and data flows using synthetic examples.
2. Implement secure enrollment, RLS and a single full care-plan/task/check-in workflow.
3. Add persistent messaging, progress, appointments, audit and clinician review workflow.
4. Add approved assessment instruments only after rights, language and scoring checks.
5. Complete access-isolation tests, recovery drill, privacy/clinical review and usability testing before a small real-patient pilot.
6. Add optional reminders, approved media and narrowly scoped AI only when operationally justified.

## Copy-ready master prompt

You are a senior software architect, security engineer and accessible healthcare-product designer. Design a single-clinician patient follow-up web application for a Sri Lankan practice. Your immediate task is architecture and UX specification only. Do not build or deploy yet. Later implementation requires an explicit instruction to proceed.

PRODUCT GOAL
Help a clinician and their patients continue agreed care between visits. Patients see daily activities, complete brief check-ins, view understandable progress and message their clinician. The clinician publishes versioned care plans, reviews submissions, tracks follow-up and communicates with each patient privately. Optimize for low digital literacy, mobile screens, limited bandwidth and shared-device privacy. This is one practice and one clinician, not a multi-clinic SaaS.

ASSUMPTIONS TO LABEL
Clinician credentials/scope, adult versus child patients, personal email availability, languages and actual patient count are unconfirmed. Use adult synthetic demo patients, Asia/Colombo and 100 active patients for initial sizing only. Do not assume that a physiotherapist can diagnose or prescribe for mental health conditions. Do not interpret the ambiguous word “meditations” as medication. State missing diagram/context and continue with explicit assumptions.

TECHNOLOGY
Prefer React + TypeScript + Vite, accessible reusable components, Tailwind CSS, a query/cache library and schema validation. Deploy static assets on Cloudflare Pages. Use Supabase Auth, Postgres, RLS, Realtime, private Storage and Edge Functions. Use scheduled SQL jobs and an idempotent outbox for recurrence/reminders. Verify current SDK versions and provider terms from official documentation. Keep one application and one database. No microservices or unnecessary alternative stacks. Vercel is an optional paid hosting alternative; never recommend Hobby for this commercial clinic. Provide a zero-cost synthetic prototype configuration and separately state production dependencies, limits and costs.

PATIENT EXPERIENCE
Four navigation items: Today, Progress, Messages, More. Today shows the next action, task list, short check-in and next appointment. Tasks support done, partly done, skipped and need help. Show plain instructions, duration and clear saved/error status. Provide an understandable care-plan timeline, clinician-shared summaries, assigned assessments, language selection and clinic help information.

CLINICIAN EXPERIENCE
Overview shows upcoming appointments, unread messages and review items with reasons. Patient workspace shows care-plan versions, submissions, progress, appointments and separately authorized private notes. Add draft/publish/archive plan states, recurrence, start/end dates, goals and review dates. Create patient invites and immutable audit history. Do not overload the first release with payments, video visits, a social feed or complex hospital administration.

DATA AND SECURITY
Provide an ERD and table design covering profiles, patients, clinician-patient links, consent, care plans and versions, goals, task templates and occurrences, task events, check-ins, appointments, conversation memberships/messages, private clinical notes, assessment definitions/versions/assignments/responses/scores, review items, notification outbox/attempts and audit events. Include keys, constraints and important indexes. RLS must deny cross-patient access for reads and writes, storage and realtime. Roles are not user-editable. Privileged functions reauthorize every target record; no service-role key reaches a browser. Require clinician MFA, secure recovery, rate limits, private files and sensitive-data-free logs. Patients cannot modify plan instructions, scoring rules or clinician notes. Document patient release/export rules separately from staff notes. No real data in demos.

SYNC AND RECURRENCE
Postgres is authoritative. Persist writes before acknowledging them. Use idempotency keys, unique recurrence occurrences and server timestamps. Realtime triggers refetch; reconnect reconciles canonical records. Display pending/failed states and allow safe retry. Store UTC instants and use Asia/Colombo calendar rules. Edits affect future occurrences and retain past plan versions. Explain conflicts, day boundaries and duplicate prevention. Cache only the public app shell initially; no offline clinical record store. Clear patient caches on logout.

SCORING AND SCREENING
Keep task participation, subjective check-ins and validated clinical instruments separate. Prefer counts such as “3 of 4 activities completed.” No tasks due means no score. Do not invent partial-task weights, overall mental-health percentages or diagnostic labels. Missing data is unknown. Build an instrument registry with authoritative source, reuse permission, age range, language/population validation, recall period, cadence, version, scoring and missing-answer rules. WHO-5, GAD-7 and adult ASRS are candidates only; enable none until verified and clinician-approved. Do not reproduce unavailable instrument text, invent questions or AI-translate validated questionnaires. Scores use deterministic server-side tested functions, never AI. Patients receive cautious screening explanations and a clinician-review path.

CLINICAL WORKFLOW
Define clinician-reviewed follow-up rules, alert ownership, operating hours, acknowledgment and resolution states. Do not promise continuous monitoring. Keep local urgent-help information clinician-verified. Caregiver/child access is a later separately consented design. Never provide autonomous diagnosis, medication dosing, prescribing or treatment changes.

AI
AI is optional and disabled by default. No patient records, check-ins, messages, identifiers or patient-derived text may go to Gemini unpaid services. A generic educational-content draft may be created without patient input, subject to provider eligibility, and published only after clinician review. Do not imply that pseudonymization establishes anonymity. Future patient-data AI requires appropriate terms, privacy review and explicit approved scope. The application must work fully without AI.

UI/UX
Create a calm minimalist interface with warm white, dark readable text and one teal/blue accent. Use 48px practical touch targets, 16–18px text, labeled icons, visible focus, keyboard support, reduced motion and WCAG 2.2 AA as the target. One main action per patient screen. Use progressive disclosure and supportive language; no rankings or streak penalties. Design English/Sinhala/Tamil localization, native-speaker review, narrow-screen behavior and loading/empty/error/offline/expired-session states. Do not equate UI translation with clinical instrument validation. Include usability scenarios for users with little app experience.

OPERATIONS
Distinguish prototype from production. Include custom SMTP, patients without email, backups of database and private files, restore testing, retention/export/deletion workflows, regional hosting and cross-border processing review, quota monitoring, incident handling and downtime workflow. Verify Sri Lankan PDPA status from current official sources; do not claim automatic compliance or reuse stale enforcement dates. Do not promise free SMS, WhatsApp, unlimited storage or guaranteed notification delivery.

REQUIRED OUTPUT NOW
1. Executive recommendation and explicit assumptions.
2. Prioritized MVP and later feature table.
3. Patient/clinician journeys and text wireframes.
4. Architecture diagram, ERD and authorization matrix.
5. Critical request flows, recurrence/sync/conflict design and screening registry.
6. Privacy, clinical and operational launch dependencies with owners.
7. Current source-backed free-tier limits and realistic upgrade triggers.
8. Phased implementation plan and concrete acceptance criteria.
9. A short list of high-impact unanswered questions, without blocking the draft.

WHEN IMPLEMENTATION IS AUTHORIZED
Build one tested end-to-end workflow at a time using synthetic data. Supply migrations, RLS policies, seed fixtures, environment-variable template, setup/deployment guide and backup/restore runbook. Test cross-patient access through direct API calls, attempted role elevation, private-note leakage, unauthorized realtime subscriptions, repeated submissions, recurrence at Colombo midnight, reconnect behavior and server-side scoring boundaries/missing responses. Test basic patient journeys and accessibility on mobile. Do not claim tests passed unless run; list remaining production blockers clearly. Stop at a reviewable demo unless real-patient launch is expressly authorized.

## Research sources

Official pages checked on 25 September 2026; terms and quotas can change.

- Cloudflare Pages pricing: https://developers.cloudflare.com/pages/functions/pricing/
- Cloudflare Pages limits: https://developers.cloudflare.com/pages/platform/limits/
- Supabase pricing: https://supabase.com/pricing
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase email delivery: https://supabase.com/docs/guides/auth/auth-smtp
- Vercel Hobby: https://vercel.com/docs/plans/hobby
- Gemini API terms: https://ai.google.dev/gemini-api/terms
- WHO-5: https://www.who.int/publications/m/item/WHO-UCN-MSD-MHE-2024.01
- Harvard ASRS information: https://www.hcp.med.harvard.edu/ncs/asrs.php
- Sri Lanka Data Protection Authority: https://www.dpa.gov.lk/
- Personal Data Protection Amendment Act 22 of 2025: https://www.parliament.lk/uploads/acts/gbills/english/6384.pdf

GAD-7 instrument approval remains an implementation research item because the official PHQ Screeners site did not return readable documentation. Clinical suitability and Sri Lankan language validation are not established by this architecture.
