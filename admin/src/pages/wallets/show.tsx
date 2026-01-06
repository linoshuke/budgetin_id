import { Show } from "@refinedev/antd";
import { useShow, useOne } from "@refinedev/core";
import { Typography, Tag } from "antd";

const { Title, Text } = Typography;

export const WalletShow = () => {
    const { queryResult } = useShow();
    const { data, isLoading } = queryResult;
    const record = data?.data;

    const { data: userData } = useOne({
        resource: "users",
        id: record?.user_id,
        queryOptions: {
            enabled: !!record?.user_id,
        },
    });

    return (
        <Show isLoading={isLoading}>
            <Title level={5}>ID</Title>
            <Text>{record?.id}</Text>

            <Title level={5}>Name</Title>
            <Text>{record?.name}</Text>

            <Title level={5}>Balance</Title>
            <Tag color={record?.balance >= 0 ? "green" : "red"}>
                Rp {Number(record?.balance || 0).toLocaleString("id-ID")}
            </Tag>

            <Title level={5}>User</Title>
            <Text>{userData?.data?.name || record?.user?.name || "-"}</Text>

            <Title level={5}>Created At</Title>
            <Text>
                {record?.created_at
                    ? new Date(record.created_at).toLocaleString()
                    : "-"}
            </Text>

            <Title level={5}>Updated At</Title>
            <Text>
                {record?.updated_at
                    ? new Date(record.updated_at).toLocaleString()
                    : "-"}
            </Text>
        </Show>
    );
};
