import { profileJobId } from './ingredient-profile-queue.service';

describe('profileJobId', () => {
  it('never contains a colon, which BullMQ rejects in custom ids', () => {
    expect(profileJobId(['a'])).not.toContain(':');
  });

  it('is deterministic for the same ids in a different order', () => {
    expect(profileJobId(['b', 'a', 'c'])).toBe('profiles-a,b,c');
    expect(profileJobId(['c', 'b', 'a'])).toBe(profileJobId(['a', 'b', 'c']));
  });

  it('hashes long id lists to a sha1 hex digest', () => {
    const ids = Array.from(
      { length: 25 },
      (_, index) =>
        `00000000-0000-0000-0000-${String(index).padStart(12, '0')}`,
    );
    const id = profileJobId(ids);
    expect(id).toMatch(/^profiles-[0-9a-f]{40}$/);
    expect(profileJobId([...ids].reverse())).toBe(id);
  });
});
