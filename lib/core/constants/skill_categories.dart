/// Shared between the talent profile builder (which categories a talent
/// can claim skill in) and the client job-posting flow (which category a
/// job requires) — a job's category must be one a talent can actually
/// verify proof against, so these lists must never drift apart.
const kSkillCategories = [
  'Software & tech',
  'Design & creative',
  'Writing & content',
  'Marketing & growth',
  'Tutoring & training',
  'Video & media',
];
