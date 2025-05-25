import { SupabaseClient } from '@supabase/supabase-js';
import { UserInfo } from './types'; // Assuming UserInfo is in ./types.ts relative to user/utils.ts

/**
 * Fetches the current credit count for a user.
 * @returns An object with UserInfo data or null if not found, and an error object if an error occurred.
 */
export async function getUserCredits(
  supabase: SupabaseClient,
  appleUserId: string
): Promise<{ data: UserInfo | null; error: any | null }> {
  const { data, error } = await supabase
    .from('users')
    .select('apple_user_id, usage_credits')
    .eq('apple_user_id', appleUserId)
    .single();

  if (error && error.code !== 'PGRST116') { // PGRST116: "single" query did not find a row
    console.error(`Utils/getUserCredits: Error fetching user ${appleUserId}:`, error);
    return { data: null, error };
  }
  if (!data) {
    return { data: null, error: null }; // User not found
  }
  return { data: { appleUserId: data.apple_user_id, credits: data.usage_credits }, error: null };
}

/**
 * Directly sets the credit count for a user.
 * @returns An object with the updated UserInfo data or null if update failed, and an error object if an error occurred.
 */
export async function setUserCredits(
  supabase: SupabaseClient,
  appleUserId: string,
  newTotalCredits: number
): Promise<{ data: UserInfo | null; error: any | null }> {
  const { data, error } = await supabase
    .from('users')
    .update({ usage_credits: newTotalCredits, updated_at: new Date().toISOString() })
    .eq('apple_user_id', appleUserId)
    .select('apple_user_id, usage_credits')
    .single();

  if (error) {
    console.error(`Utils/setUserCredits: Error setting credits for user ${appleUserId}:`, error);
    return { data: null, error };
  }
  if (!data) {
    console.error(`Utils/setUserCredits: User ${appleUserId} not found after update attempt.`);
    return { data: null, error: { message: 'User not found after update.' } };
  }
  return { data: { appleUserId: data.apple_user_id, credits: data.usage_credits }, error: null };
}

/**
 * Modifies a user's credits by a specified amount (can be positive or negative).
 * Fetches current credits, calculates new total, then updates.
 * @returns An object with the updated UserInfo data or null if modification failed, and an error object if an error occurred.
 */
export async function modifyCredits(
  supabase: SupabaseClient,
  appleUserId: string,
  amountToModify: number
): Promise<{ data: UserInfo | null; error: any | null }> {
  // 1. Fetch current credits
  const { data: currentUserData, error: fetchError } = await getUserCredits(supabase, appleUserId);

  if (fetchError) {
    console.error(`Utils/modifyCredits: Fetch error for user ${appleUserId} before modification:`, fetchError);
    return { data: null, error: fetchError };
  }
  if (!currentUserData) {
    console.error(`Utils/modifyCredits: User ${appleUserId} not found for credit modification.`);
    return { data: null, error: { message: 'User not found for credit modification' } };
  }

  const currentCredits = currentUserData.credits;
  const newTotalCredits = currentCredits + amountToModify;

  // Ensure credits don't go below zero through this generic modify function
  // Specific logic for decrementing (e.g. not allowing if already 0) should be handled by the caller if needed.
  if (newTotalCredits < 0) {
      console.warn(`Utils/modifyCredits: Attempt to set credits to ${newTotalCredits} for user ${appleUserId}. Setting to 0 instead.`);
      // return { data: null, error: { message: 'Credit modification would result in negative balance.' } };
  }

  // 2. Update with new total
  return setUserCredits(supabase, appleUserId, Math.max(0, newTotalCredits));
} 