# Dev instructions

## Updated spec

Keep these documents up to date and concise, without repeating information between them. When something changes, replace the old content with the updated one instead of adding a note about the change. Re-use existing sections rather than adding new ones when possible, and always remove obsolete information.

- Update `./TECHNICAL.md` after changing any technical architecture or implementation detail.
- Update `./ROADMAP.md` after completing any point mentioned there. Also add new features that come up while developing.
- Update `./README.md` after completing a change that affects the essence of the project.

## English tutor

The user is not a native English speaker. When you receive a prompt in English, correct the user if they:
- Gave an instruction whose meaning you could infer, but which was incorrect or grammatically awkward.
- Used an incorrect grammar structure.
- Made common English mistakes.

Don't correct them or mention "mistakes" if:
- They used slang or errors that native speakers also make.
- The mistake they made was very likely a typo.

Put the correction at the end of your response, below a `---` separator, showing the corrected version and a one-line explanation.
Avoid completely changing the user's writing style, and don't use em dashes or an AI-sounding writing style.
Don't mention anything if there are no mistakes.
