/**
 * Types de l'API FitForge, cote console.
 *
 * Ils reproduisent les records Java du backend. Ils sont ecrits a la main
 * plutot que generes depuis l'OpenAPI : la console n'utilise qu'une
 * fraction de l'API (une vingtaine de routes sur plus de quatre-vingts),
 * et un generateur ferait entrer tout le reste — les exercices, la
 * nutrition, le sommeil — dans un fichier que personne ne relit.
 *
 * La contrepartie est reelle : si un DTO Java change, rien ici ne le
 * signale a la compilation. C'est pourquoi chaque type porte le nom de la
 * classe Java correspondante, pour qu'une recherche par nom retrouve les
 * deux cotes d'un coup.
 */

// ── Enumerations (miroir de common/enums) ──────────────────────────

export type Role = "ADHERENT" | "COACH" | "ADMIN";

export type CoachStatus = "DRAFT" | "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED";

export type CoachDocumentType = "IDENTITY" | "DIPLOMA" | "CERTIFICATION" | "OTHER";

export type ProblemCategory =
  | "BUG"
  | "ACCOUNT"
  | "CONTENT"
  | "ABUSE"
  | "SUGGESTION"
  | "OTHER";

export type ProblemStatus = "NEW" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";

export type AdminNotificationType =
  | "COACH_APPLICATION_SUBMITTED"
  | "MEMBER_REGISTERED"
  | "PROBLEM_REPORTED";

export type AiFeature =
  | "COACH_CHAT"
  | "MEAL_PHOTO"
  | "MEAL_VOICE"
  | "MEAL_TEXT"
  | "PROGRAM_GENERATION"
  | "HEALTH_PROBE";

// ── Enveloppe paginee (common/dto/PageResponse) ────────────────────

export interface PageResponse<T> {
  items: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
}

// ── Compte connecte (user/dto/AccountResponse) ─────────────────────

export interface Account {
  id: string;
  email: string;
  fullName: string;
  phoneNumber: string | null;
  avatarUrl: string | null;
  role: Role;
  emailVerified: boolean;
  createdAt: string;
  lastLoginAt: string | null;
}

// ── Candidatures coach (admin/dto) ─────────────────────────────────

export interface CoachApplicationSummary {
  profileId: string;
  userId: string;
  fullName: string;
  email: string;
  avatarUrl: string | null;
  status: CoachStatus;
  headline: string | null;
  city: string | null;
  yearsExperience: number | null;
  documentCount: number;
  submittedAt: string | null;
  reviewedAt: string | null;
  registeredAt: string;
}

export interface CoachDocument {
  id: string;
  type: CoachDocumentType;
  label: string | null;
  originalName: string | null;
  contentType: string | null;
  sizeBytes: number | null;
  uploadedAt: string;
}

export interface Certification {
  id: string;
  title: string;
  organization: string | null;
  year: number | null;
  credentialUrl: string | null;
}

export interface Education {
  id: string;
  degree: string;
  institution: string | null;
  fieldOfStudy: string | null;
  year: number | null;
}

export interface Experience {
  id: string;
  title: string;
  organization: string | null;
  startYear: number | null;
  endYear: number | null;
  description: string | null;
}

export interface CoachApplicationDetail {
  profileId: string;
  userId: string;
  fullName: string;
  email: string;
  phoneNumber: string | null;
  avatarUrl: string | null;
  registeredAt: string;
  emailVerified: boolean;
  headline: string | null;
  bio: string | null;
  yearsExperience: number | null;
  hourlyRate: number | null;
  city: string | null;
  specialties: string[];
  certifications: Certification[];
  educations: Education[];
  experiences: Experience[];
  documents: CoachDocument[];
  status: CoachStatus;
  submittedAt: string | null;
  reviewedAt: string | null;
  reviewedByName: string | null;
  rejectionReason: string | null;
}

// ── Membres (admin/dto) ────────────────────────────────────────────

export interface UserSummary {
  id: string;
  fullName: string;
  email: string;
  avatarUrl: string | null;
  role: Role;
  enabled: boolean;
  emailVerified: boolean;
  coachStatus: CoachStatus | null;
  createdAt: string;
  lastLoginAt: string | null;
}

export interface UserDetail {
  id: string;
  fullName: string;
  email: string;
  phoneNumber: string | null;
  avatarUrl: string | null;
  role: Role;
  enabled: boolean;
  emailVerified: boolean;
  createdAt: string;
  lastLoginAt: string | null;
  lastSeenAt: string | null;
  gender: string | null;
  birthDate: string | null;
  age: number | null;
  heightCm: number | null;
  currentWeightKg: number | null;
  goal: string | null;
  onboardingCompleted: boolean;
  coachStatus: CoachStatus | null;
  coachProfileId: string | null;
  workoutLogCount: number;
  lastWorkoutDate: string | null;
  nutritionEntryCount: number;
  sleepEntryCount: number;
  programCount: number;
}

// ── Signalements (admin/dto) ───────────────────────────────────────

export interface ProblemReport {
  id: string;
  reporterId: string;
  reporterName: string;
  reporterEmail: string;
  reporterAvatarUrl: string | null;
  reporterRole: Role;
  category: ProblemCategory;
  subject: string;
  description: string;
  attachmentUrl: string | null;
  platform: string | null;
  appVersion: string | null;
  status: ProblemStatus;
  adminResponse: string | null;
  handledByName: string | null;
  handledAt: string | null;
  createdAt: string;
  updatedAt: string | null;
}

// ── Notifications (admin/dto) ──────────────────────────────────────

export interface AdminNotification {
  id: string;
  type: AdminNotificationType;
  title: string;
  body: string | null;
  targetId: string | null;
  readAt: string | null;
  createdAt: string;
}

// ── Tableau de bord (admin/dto) ────────────────────────────────────

export interface DailyCount {
  date: string;
  count: number;
}

export interface Dashboard {
  pendingCoachApplications: number;
  newProblemReports: number;
  inProgressProblemReports: number;
  unreadNotifications: number;
  totalMembers: number;
  totalCoaches: number;
  approvedCoaches: number;
  inactiveAccounts: number;
  newAccounts30d: number;
  activeAccounts7d: number;
  workoutsLogged30d: number;
  mealsLogged30d: number;
  sleepEntries30d: number;
  aiCalls24h: number;
  aiFailures24h: number;
  registrationsPerDay: DailyCount[];
}

// ── Sante de l'IA (admin/dto) ──────────────────────────────────────

export interface FeatureHealth {
  feature: AiFeature;
  label: string;
  calls24h: number;
  failures24h: number;
  failureRate24h: number;
  avgLatencyMs24h: number | null;
  maxLatencyMs24h: number | null;
  calls7d: number;
  failures7d: number;
  failureRate7d: number;
}

export interface AiFailure {
  feature: AiFeature;
  errorType: string | null;
  latencyMs: number;
  occurredAt: string;
}

export interface AiHealth {
  configured: boolean;
  model: string | null;
  programModel: string | null;
  features: FeatureHealth[];
  recentFailures: AiFailure[];
  generatedAt: string;
}

export interface ProbeResult {
  reachable: boolean;
  latencyMs: number;
  error: string | null;
}
