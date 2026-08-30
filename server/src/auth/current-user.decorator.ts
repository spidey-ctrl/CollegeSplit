import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): DecodedIdToken => {
    const request = context.switchToHttp().getRequest();
    return request.user;
  },
);
