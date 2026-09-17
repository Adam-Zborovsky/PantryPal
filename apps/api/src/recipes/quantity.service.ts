import { BadRequestException, Injectable } from '@nestjs/common';
import { Decimal } from '@prisma/client/runtime/library';
import { formatDecimal } from './units';

export interface QuantityRange {
  min: string | null;
  max: string | null;
  unit: string | null;
  originalText: string;
}

@Injectable()
export class QuantityService {
  scale(
    quantity: QuantityRange,
    originalServings: string,
    targetServings: string,
  ): QuantityRange {
    const original = this.decimal(originalServings);
    const target = this.decimal(targetServings);
    if (original.lte(0) || target.lte(0))
      throw new BadRequestException('Servings must be positive values.');
    const factor = target.div(original);
    return {
      ...quantity,
      min:
        quantity.min === null
          ? null
          : this.format(this.decimal(quantity.min).mul(factor)),
      max:
        quantity.max === null
          ? null
          : this.format(this.decimal(quantity.max).mul(factor)),
    };
  }

  private decimal(value: string) {
    if (!/^-?\d+(\.\d+)?$/.test(value))
      throw new BadRequestException('Quantity must be a decimal value.');
    return new Decimal(value);
  }

  private format(value: Decimal) {
    return formatDecimal(value);
  }
}
