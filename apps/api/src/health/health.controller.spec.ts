import { HealthController } from './health.controller';

describe('HealthController', () => {
  it('reports that the process is live', () => {
    expect(new HealthController().live()).toEqual({ status: 'ok' });
  });
});
