import type { UserPublic } from "@/client"

const role = (user?: UserPublic | null) =>
  user?.is_superuser ? "admin" : user?.role

export const canCreateUsers = (user?: UserPublic | null) => role(user) === "admin"

export const canListUsers = (user?: UserPublic | null) =>
  role(user) === "admin" || role(user) === "manager"

export const canViewMetrics = canListUsers
