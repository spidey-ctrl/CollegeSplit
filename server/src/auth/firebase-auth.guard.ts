import { Injectable } from '@nestjs/common';
import {
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken } from 'firebase-admin/auth';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor() {
    if (getApps().length === 0) {
      const account = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (account) {
        initializeApp({
          credential: cert(JSON.parse(account)),
        });
      } else {
        // ID-token verification only needs the project ID (public signing keys
        // are fetched from Google). Cloud Run / gcloud ADC can still supply the
        // project ID implicitly; we pass it explicitly so local dev works too.
        initializeApp({
          projectId: process.env.FIREBASE_PROJECT_ID ?? 'collegesplit',
        });
      }
    }
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest();
    const header: string | undefined = req.headers['authorization'];
    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }

    const token = header.slice('Bearer '.length).trim();
    let decoded: DecodedIdToken;
    try {
      decoded = await getAuth().verifyIdToken(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }

    req.user = decoded;
    return true;
  }
}
