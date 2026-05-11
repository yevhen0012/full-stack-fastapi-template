import { redirect } from "@tanstack/react-router"

import { ApiError, UsersService, type UserPublic } from "@/client"

/**
 * Loads the current user inside router beforeLoad hooks. Auth failures clear
 * a stale token and redirect to login so the route error boundary is avoided.
 */
export async function readUserMeForGuard(): Promise<UserPublic> {
  try {
    return await UsersService.readUserMe()
  } catch (error) {
    if (error instanceof ApiError && [401, 403].includes(error.status)) {
      localStorage.removeItem("access_token")
      throw redirect({ to: "/login" })
    }
    throw error
  }
}
