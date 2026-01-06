import { Show } from "@refinedev/antd";
import { useShow } from "@refinedev/core";
import { Typography } from "antd";

const { Title, Text } = Typography;

export const UserShow = () => {
    const { queryResult } = useShow();
    const { data, isLoading } = queryResult;
    const record = data?.data;

    return (
        <Show isLoading={isLoading}>
            <Title level={5}>ID</Title>
            <Text>{record?.id}</Text>

            <Title level={5}>Name</Title>
            <Text>{record?.name}</Text>

            <Title level={5}>Email</Title>
            <Text>{record?.email}</Text>

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
