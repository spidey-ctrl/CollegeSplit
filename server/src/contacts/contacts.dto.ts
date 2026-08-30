import { BadRequestException } from '@nestjs/common';

export interface SetPhoneDto {
  phoneNumber: string | null;
}

export function assertSetPhone(body: unknown): asserts body is SetPhoneDto {
  if (typeof body !== 'object' || body === null) {
    throw new BadRequestException('Request body must be a JSON object');
  }
  const b = body as Record<string, unknown>;
  if (b.phoneNumber === undefined) {
    throw new BadRequestException('phoneNumber is required');
  }
  if (b.phoneNumber !== null && typeof b.phoneNumber !== 'string') {
    throw new BadRequestException('phoneNumber must be a string or null');
  }
}
