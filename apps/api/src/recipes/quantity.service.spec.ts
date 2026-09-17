import { QuantityService } from './quantity.service';

describe('QuantityService', () => {
  const service = new QuantityService();
  it('scales decimal ranges at both ends', () => {
    expect(
      service.scale(
        { min: '1.25', max: '2.5', unit: 'cup', originalText: '1¼–2½ cups' },
        '4',
        '6',
      ),
    ).toMatchObject({ min: '1.875', max: '3.75' });
  });
  it('keeps trailing zeros of whole-number results', () => {
    expect(
      service.scale(
        { min: '100', max: '250', unit: 'g', originalText: '100–250 g' },
        '2',
        '4',
      ),
    ).toMatchObject({ min: '200', max: '500' });
  });
});
