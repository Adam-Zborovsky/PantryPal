import * as argon2 from 'argon2';
import { PrismaClient } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import { config } from 'dotenv';

config({ path: '../../.env' });

const prisma = new PrismaClient();
const hash = (value: string) =>
  createHash('sha256').update(value.trim()).digest('base64url');

async function main() {
  const [command, ...args] = process.argv.slice(2);
  if (command === 'beta-invite') {
    const days = Number(args[0] ?? 14);
    if (!Number.isInteger(days) || days < 1 || days > 90)
      throw new Error('Expiry days must be an integer from 1 through 90.');
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    await prisma.betaInvite.create({
      data: { tokenHash: hash(token), expiresAt },
    });
    process.stdout.write(
      `Beta invite (show once): ${token}\nExpires: ${expiresAt.toISOString()}\n`,
    );
    return;
  }
  if (command === 'reset-password') {
    const [email, password] = args;
    if (!email || !password || password.length < 12)
      throw new Error('Usage: reset-password <email> <new-password-min-12>.');
    const account = await prisma.account.findUnique({
      where: { email: email.trim().toLowerCase() },
    });
    if (!account) throw new Error('No account exists for that email.');
    await prisma.$transaction([
      prisma.account.update({
        where: { id: account.id },
        data: {
          passwordHash: await argon2.hash(password, { type: argon2.argon2id }),
        },
      }),
      prisma.session.updateMany({
        where: { accountId: account.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
    process.stdout.write(
      `Password reset and all active sessions revoked for ${account.email}.\n`,
    );
    return;
  }
  throw new Error(
    'Usage: cli beta-invite [expiry-days] | cli reset-password <email> <new-password-min-12>',
  );
}

void main()
  .catch((error: unknown) => {
    process.stderr.write(
      `${error instanceof Error ? error.message : 'Operator command failed.'}\n`,
    );
    process.exitCode = 1;
  })
  .finally(async () => prisma.$disconnect());
