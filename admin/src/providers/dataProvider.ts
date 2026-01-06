import type { DataProvider } from "@refinedev/core";
import axios from "axios";

const API_URL = "/api";

const axiosInstance = axios.create({
    baseURL: API_URL,
    headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
    },
    withCredentials: true,
});

// Add token to requests if available
axiosInstance.interceptors.request.use((config) => {
    const token = localStorage.getItem("access_token");
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

export const dataProvider: DataProvider = {
    getList: async ({ resource, pagination, filters, sorters }) => {
        const { current = 1, pageSize = 10 } = pagination ?? {};

        const params: Record<string, unknown> = {
            page: current,
            per_page: pageSize,
        };

        // Handle sorting
        if (sorters && sorters.length > 0) {
            params.sort_by = sorters[0].field;
            params.sort_order = sorters[0].order;
        }

        // Handle filters
        if (filters) {
            filters.forEach((filter) => {
                if ("field" in filter) {
                    params[filter.field] = filter.value;
                }
            });
        }

        const { data } = await axiosInstance.get(`/${resource}`, { params });

        return {
            data: data.data || data,
            total: data.meta?.total || data.total || data.length,
        };
    },

    getOne: async ({ resource, id }) => {
        const { data } = await axiosInstance.get(`/${resource}/${id}`);
        return {
            data: data.data || data,
        };
    },

    create: async ({ resource, variables }) => {
        const { data } = await axiosInstance.post(`/${resource}`, variables);
        return {
            data: data.data || data,
        };
    },

    update: async ({ resource, id, variables }) => {
        const { data } = await axiosInstance.put(`/${resource}/${id}`, variables);
        return {
            data: data.data || data,
        };
    },

    deleteOne: async ({ resource, id }) => {
        const { data } = await axiosInstance.delete(`/${resource}/${id}`);
        return {
            data: data.data || data,
        };
    },

    getApiUrl: () => API_URL,

    getMany: async ({ resource, ids }) => {
        const { data } = await axiosInstance.get(`/${resource}`, {
            params: { ids: ids.join(",") },
        });
        return {
            data: data.data || data,
        };
    },

    createMany: async ({ resource, variables }) => {
        const responses = await Promise.all(
            variables.map((vars) => axiosInstance.post(`/${resource}`, vars))
        );
        return {
            data: responses.map((res) => res.data.data || res.data),
        };
    },

    deleteMany: async ({ resource, ids }) => {
        await Promise.all(
            ids.map((id) => axiosInstance.delete(`/${resource}/${id}`))
        );
        return {
            data: [],
        };
    },

    updateMany: async ({ resource, ids, variables }) => {
        const responses = await Promise.all(
            ids.map((id) => axiosInstance.put(`/${resource}/${id}`, variables))
        );
        return {
            data: responses.map((res) => res.data.data || res.data),
        };
    },
};

export { axiosInstance };
