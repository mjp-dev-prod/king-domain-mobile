/// One place for the plain-English explanation of each term the app uses, so the same word is explained the same way
/// everywhere (wording pass, 2026-11-09). Each is shown behind a small "i" (InfoTip). Short, no rule-book words, and
/// only what is true today: change the rule in the code first, then the words here.
class Tip {
  final String title;
  final String body;
  const Tip(this.title, this.body);
}

class Glossary {
  Glossary._();

  static const milestones = Tip(
    'What are milestones?',
    'Milestones split a bigger job into 2 to 5 stages, each with its own price and number of days. For a website, that could be Design first, then Build. The client pays for a stage before it starts, and it is released to the talent when the client approves it. The client can stop after any approved stage, so nobody is exposed for more than one stage at a time.',
  );

  static const verifiedSkill = Tip(
    'What does verified mean?',
    'A person checked that the work is really yours, and two reviewers who work in this skill judged it good. Then you can apply to jobs in it, and clients can see you are verified.',
  );

  static const firstCheck = Tip(
    'The first check',
    'Before the reviewers see anything, a person checks the work is really yours, using your walkthrough video and how you made it. This keeps the reviews fair for everyone who did their own work.',
  );

  static const walkthrough = Tip(
    'Why a walkthrough video?',
    'You explain the work on camera in 2 to 3 minutes: what you made, and how. Anyone can borrow a picture. Explaining the work yourself is the strongest sign it is yours.',
  );

  static const notYet = Tip(
    'What does "Not yet" mean?',
    'Not yet is not never. The reviewers listed what to improve. Change the work and send it again. If you send the same work again without changing it, you are locked out of that skill for 2 months, then 3.',
  );

  static const startProof = Tip(
    'What is a start proof?',
    'Before the main work, the talent shows a first sample, like a rough draft. The client checks it matches the brief. When they accept it, the first 20% of the payment is released so the talent can keep going. If it is off, the client says so and the talent fixes it.',
  );

  static const changeRounds = Tip(
    'What are rounds of changes?',
    'After work is delivered, the client can ask for changes up to 2 times. That keeps the job fair for both sides: the client gets a say, and the talent is not asked to redo it forever. If it still is not right after that, an admin can look at it.',
  );

  static const heldPayment = Tip(
    'Why is the money held?',
    'When the client pays, King Domain holds the money. It is not given to the talent until the client approves the work. If something goes wrong, the team can step in. That protects both people.',
  );

  static const serviceFee = Tip(
    'What is the 10%?',
    'It is King Domain\'s fee, and the client pays it on top of the price. The talent receives the full price.',
  );

  static const proven = Tip(
    'What is Proven?',
    'Proven is a level you earn in a skill after 3 finished jobs in it: delivered on time, no dispute lost, and every client recommending you. It is earned from real jobs, never bought.',
  );

  static const usageRights = Tip(
    'What may the work be used for?',
    'What the client is allowed to do with the finished work, for example post it on their own pages, or use it in paid ads for a while. Agreeing it now stops arguments later.',
  );
}
