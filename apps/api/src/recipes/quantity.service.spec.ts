import { QuantityService } from './quantity.service';

describe('QuantityService', () => {
  const service = new QuantityService();
  it('scales decimal ranges at both ends', () => {
    expect(service.scale({ min: '1.25', max: '2.5', unit: 'cup', originalText: '1¼–2½ cups' }, '4', '6')).toMatchObject({ min: '1.875', max: '3.75' });
  });
  it('never merges incompatible dimensions', () => expect(service.compatible({ min: '1', max: null, unit: 'g', originalText: '' }, { min: '1', max: null, unit: 'ml', originalText: '' })).toBe(false));
});
