import type { AuthProvider } from "@refinedev/core";
import { axiosInstance } from "./dataProvider";

export const authProvider: AuthProvider = {
    login: async ({ email, password }) => {
        try {
            const { data } = await axiosInstance.post("/auth/login", {
                email,
                password,
            });

            if (data.access_token) {
                localStorage.setItem("access_token", data.access_token);
                localStorage.setItem("user", JSON.stringify(data.user));

                return {
                    success: true,
                    redirectTo: "/",
                };
            }

            return {
                success: false,
                error: {
                    name: "LoginError",
                    message: "Invalid credentials",
                },
            };
        } catch (error: unknown) {
            const err = error as { response?: { data?: { message?: string } } };
            return {
                success: false,
                error: {
                    name: "LoginError",
                    message: err.response?.data?.message || "Login failed",
                },
            };
        }
    },

    logout: async () => {
        try {
            await axiosInstance.post("/auth/logout");
        } catch {
            // Ignore logout errors
        }

        localStorage.removeItem("access_token");
        localStorage.removeItem("user");

        return {
            success: true,
            redirectTo: "/login",
        };
    },

    check: async () => {
        const token = localStorage.getItem("access_token");

        if (!token) {
            return {
                authenticated: false,
                redirectTo: "/login",
            };
        }

        try {
            await axiosInstance.get("/auth/me");
            return {
                authenticated: true,
            };
        } catch {
            localStorage.removeItem("access_token");
            localStorage.removeItem("user");
            return {
                authenticated: false,
                redirectTo: "/login",
            };
        }
    },

    getIdentity: async () => {
        const user = localStorage.getItem("user");
        if (user) {
            const parsed = JSON.parse(user);
            return {
                id: parsed.id,
                name: parsed.name,
                email: parsed.email,
                avatar: parsed.avatar,
            };
        }
        return null;
    },

    getPermissions: async () => {
        const user = localStorage.getItem("user");
        if (user) {
            const parsed = JSON.parse(user);
            return parsed.role;
        }
        return null;
    },

    onError: async (error) => {
        const status = (error as { status?: number }).status;
        if (status === 401 || status === 403) {
            return {
                logout: true,
                redirectTo: "/login",
            };
        }
        return { error };
    },
};
