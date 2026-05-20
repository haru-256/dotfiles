# User Phone Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add phone number validation to the user update API in the actual NestJS application under `schedule-panel/apps/batch-manager/`.

**Architecture:** The requested `src/api/user.js` does not exist, and this repository has no existing user module. Implement a minimal NestJS `UserModule` following the existing Batch module structure: DTO validation with `class-validator`, a controller update endpoint, a Prisma-backed service, and app module registration. Use `@IsPhoneNumber('JP')` for the update DTO so Japanese domestic formats and `+81` international formats are accepted while non-JP numbers are rejected.

**Tech Stack:** NestJS, TypeScript, Prisma, PostgreSQL, class-validator, Jest.

---

## Decisions

- **Actual target path:** Do not create `src/api/user.js`. Work under `schedule-panel/apps/batch-manager/src/user/`.
- **Country validation:** Use `@IsPhoneNumber('JP')` by default. This is the safest recommendation for a Japan-focused app because it accepts values like `090-1234-5678` and `+81 90-1234-5678`, while rejecting `+1 ...` numbers.
- **Update optionality:** Use `@IsOptional()` with `@IsPhoneNumber('JP')` in `UpdateUserDto`, so PATCH requests can omit `phoneNumber` but invalid supplied values fail validation.
- **Storage format:** Store the submitted string as-is in `phoneNumber`. Do not normalize to E.164 in this slice because no existing user model or normalization policy exists. Add E.164 normalization later only if the product requires canonical storage.
- **API shape:** Implement `PATCH /user/:id` to update a user by ID, mirroring the existing Batch controller/service pattern.
- **Git:** Do not commit unless the user explicitly asks.

## File Structure

Create:
- `schedule-panel/apps/batch-manager/src/user/dto/create-user.dto.ts` — required user fields for create-style validation and DTO reuse.
- `schedule-panel/apps/batch-manager/src/user/dto/update-user.dto.ts` — partial update DTO with optional `phoneNumber` validation.
- `schedule-panel/apps/batch-manager/src/user/entities/user.entity.ts` — user entity type matching Prisma user fields.
- `schedule-panel/apps/batch-manager/src/user/user.controller.ts` — `PATCH /user/:id` endpoint.
- `schedule-panel/apps/batch-manager/src/user/user.service.ts` — Prisma update operation.
- `schedule-panel/apps/batch-manager/src/user/user.module.ts` — module wiring.
- `schedule-panel/apps/batch-manager/src/user/user.controller.spec.ts` — controller unit tests.
- `schedule-panel/apps/batch-manager/src/user/user.service.spec.ts` — service unit tests.

Modify:
- `schedule-panel/apps/batch-manager/prisma/schema.prisma` — add `User` model with `phoneNumber`.
- `schedule-panel/apps/batch-manager/src/app.module.ts` — import/register `UserModule`.

## Implementation Tasks

### Task 1: Add DTO phone validation tests first

**Files:**
- Create: `schedule-panel/apps/batch-manager/src/user/dto/create-user.dto.ts`
- Create: `schedule-panel/apps/batch-manager/src/user/dto/update-user.dto.ts`
- Test through controller spec in Task 4 if the project does not have DTO-only tests.

- [ ] **Step 1: Create `CreateUserDto` with JP phone validation**

```ts
import { IsNotEmpty, IsPhoneNumber, IsString } from 'class-validator';

export class CreateUserDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsPhoneNumber('JP')
  phoneNumber: string;
}
```

- [ ] **Step 2: Create `UpdateUserDto` using the existing Batch update DTO pattern**

```ts
import { PartialType } from '@nestjs/mapped-types';
import { IsOptional, IsPhoneNumber } from 'class-validator';
import { CreateUserDto } from './create-user.dto';

export class UpdateUserDto extends PartialType(CreateUserDto) {
  @IsOptional()
  @IsPhoneNumber('JP')
  phoneNumber?: string;
}
```

- [ ] **Step 3: Confirm validation semantics**

Expected behavior:
- `{}` passes DTO validation for update.
- `{ phoneNumber: '090-1234-5678' }` passes.
- `{ phoneNumber: '+81 90-1234-5678' }` passes.
- `{ phoneNumber: '+1 212-555-0100' }` fails.
- `{ phoneNumber: '' }` fails.

### Task 2: Add Prisma user model

**Files:**
- Modify: `schedule-panel/apps/batch-manager/prisma/schema.prisma`

- [ ] **Step 1: Add a minimal `User` model**

Add this model, adjusting only if the existing schema uses a different ID/default timestamp convention:

```prisma
model User {
  id          Int      @id @default(autoincrement())
  name        String
  phoneNumber String?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

- [ ] **Step 2: Generate Prisma artifacts**

Run from `schedule-panel/apps/batch-manager/`:

```bash
npx prisma generate
```

Expected: Prisma Client generation succeeds.

- [ ] **Step 3: Create migration only if this project tracks Prisma migrations**

If `schedule-panel/apps/batch-manager/prisma/migrations/` already exists, run:

```bash
npx prisma migrate dev --name add_user_phone_number --create-only
```

Expected: a new migration directory is created. If migrations are not tracked in this project, do not invent migration structure; leave only `schema.prisma` changed and report that no existing migration directory was present.

### Task 3: Implement User service/module/entity

**Files:**
- Create: `schedule-panel/apps/batch-manager/src/user/entities/user.entity.ts`
- Create: `schedule-panel/apps/batch-manager/src/user/user.service.ts`
- Create: `schedule-panel/apps/batch-manager/src/user/user.module.ts`

- [ ] **Step 1: Add entity**

```ts
export class User {
  id: number;
  name: string;
  phoneNumber?: string | null;
  createdAt: Date;
  updatedAt: Date;
}
```

- [ ] **Step 2: Add service following the existing Batch service Prisma pattern**

```ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  update(id: number, updateUserDto: UpdateUserDto) {
    return this.prisma.user.update({
      where: { id },
      data: updateUserDto,
    });
  }
}
```

If the existing Batch service imports `PrismaService` from a different path, use that exact path instead.

- [ ] **Step 3: Add module**

```ts
import { Module } from '@nestjs/common';
import { UserController } from './user.controller';
import { UserService } from './user.service';

@Module({
  controllers: [UserController],
  providers: [UserService],
})
export class UserModule {}
```

### Task 4: Implement update controller and tests

**Files:**
- Create: `schedule-panel/apps/batch-manager/src/user/user.controller.ts`
- Create: `schedule-panel/apps/batch-manager/src/user/user.controller.spec.ts`

- [ ] **Step 1: Add controller**

```ts
import { Body, Controller, Param, Patch } from '@nestjs/common';
import { UpdateUserDto } from './dto/update-user.dto';
import { UserService } from './user.service';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateUserDto: UpdateUserDto) {
    return this.userService.update(+id, updateUserDto);
  }
}
```

- [ ] **Step 2: Add controller unit test mirroring Batch controller spec style**

Use the same testing imports and mock pattern as `schedule-panel/apps/batch-manager/src/batch/batch.controller.spec.ts`. Required assertions:

```ts
it('should update a user with a JP phone number', async () => {
  const dto = { phoneNumber: '090-1234-5678' };
  const result = { id: 1, name: 'Test User', phoneNumber: '090-1234-5678' };
  jest.spyOn(service, 'update').mockResolvedValue(result as never);

  await expect(controller.update('1', dto)).resolves.toBe(result);
  expect(service.update).toHaveBeenCalledWith(1, dto);
});
```

- [ ] **Step 3: Add DTO validation test if current test setup supports `validate` from `class-validator`**

```ts
import { validate } from 'class-validator';
import { UpdateUserDto } from './dto/update-user.dto';

it('rejects non-JP phone numbers', async () => {
  const dto = new UpdateUserDto();
  dto.phoneNumber = '+1 212-555-0100';

  const errors = await validate(dto);

  expect(errors).toHaveLength(1);
  expect(errors[0].property).toBe('phoneNumber');
});
```

### Task 5: Register module and verify

**Files:**
- Modify: `schedule-panel/apps/batch-manager/src/app.module.ts`

- [ ] **Step 1: Register `UserModule`**

Add:

```ts
import { UserModule } from './user/user.module';
```

Then include `UserModule` in the `imports` array, preserving existing module order/style.

- [ ] **Step 2: Run focused tests**

Run from `schedule-panel/apps/batch-manager/` using the package manager already used by the project:

```bash
npm test -- user
```

Expected: user controller/service/DTO tests pass. If the project uses a different script, use the closest existing Jest test script in `package.json` and report the exact command/output.

- [ ] **Step 3: Run broader verification**

Run from `schedule-panel/apps/batch-manager/`:

```bash
npm test
```

Expected: existing Batch tests and new User tests pass.

## Acceptance Criteria

- No `src/api/user.js` file is created.
- `schedule-panel/apps/batch-manager/src/user/` contains a NestJS user module matching existing Batch module conventions.
- `PATCH /user/:id` accepts omitted `phoneNumber`, valid JP domestic numbers, and valid `+81` numbers.
- `PATCH /user/:id` rejects invalid/non-JP phone numbers via DTO validation.
- Prisma schema includes a `User` model with nullable `phoneNumber`.
- User module is registered in `AppModule`.
- Relevant tests pass or any environment/tooling blocker is reported with exact command output.

## Non-Goals

- Do not implement authentication/authorization.
- Do not implement full user CRUD beyond the update endpoint needed for this task.
- Do not normalize phone numbers to E.164 in this slice.
- Do not change existing Batch behavior.
- Do not commit changes.

## Implementation Log
<!-- Implementer appends one line per attempt: [YYYY-MM-DD] attempt #N -> STATUS | commit-or-failure-signature -->

## Review Findings
<!-- This template is also defined in commands/plan-v2.md. Keep them in sync on every edit. -->

### Reviewer Raw Findings
<!-- Planner V2 copies @reviewer_v2's structured findings verbatim here when invoking @reviewer_v2 during a workflow. Direct /review-*-v2 calls do not write here. Raw findings are review input, not implementation instructions. -->

### Planner V2 Adjudication
<!-- Planner V2 appends adjudication tables for v2 workflow reviews. Only ACCEPT rows are implementation instructions: | ID | Severity | Decision | Reason | Action | -->

## Deviations from Plan
<!-- Implementer documents intentional deviations and reasons. -->

## Open Questions
<!-- Any agent adds questions for planner_v2 or oracle_v2. -->

- [product] Confirm whether Japan-only validation is correct long-term, or whether international/E.164-only input should replace `@IsPhoneNumber('JP')`.
