import { z } from "zod";

export const signInSchema = z.object({
  email: z.email("Format email tidak valid.").max(254),
  password: z.string().min(1, "Kata sandi wajib diisi.").max(72),
});

export const signUpSchema = z.object({
  fullName: z
    .string()
    .trim()
    .min(2, "Nama minimal 2 karakter.")
    .max(100, "Nama maksimal 100 karakter."),
  email: z.email("Format email tidak valid.").max(254),
  password: z
    .string()
    .min(8, "Kata sandi minimal 8 karakter.")
    .max(72, "Kata sandi maksimal 72 karakter."),
});

export type AuthFormState = {
  message?: string;
  fieldErrors?: Partial<Record<"fullName" | "email" | "password", string[]>>;
  values?: { fullName?: string; email?: string };
};
