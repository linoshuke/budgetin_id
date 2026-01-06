import {
    List,
    useTable,
    EditButton,
    ShowButton,
    DeleteButton,
} from "@refinedev/antd";
import { Table, Space } from "antd";

export const UserList = () => {
    const { tableProps } = useTable({
        syncWithLocation: true,
    });

    return (
        <List>
            <Table {...tableProps} rowKey="id">
                <Table.Column dataIndex="id" title="ID" sorter />
                <Table.Column dataIndex="name" title="Name" sorter />
                <Table.Column dataIndex="email" title="Email" sorter />
                <Table.Column
                    dataIndex="created_at"
                    title="Created At"
                    render={(value) => new Date(value).toLocaleDateString()}
                />
                <Table.Column
                    title="Actions"
                    render={(_, record: { id: number }) => (
                        <Space>
                            <EditButton hideText size="small" recordItemId={record.id} />
                            <ShowButton hideText size="small" recordItemId={record.id} />
                            <DeleteButton hideText size="small" recordItemId={record.id} />
                        </Space>
                    )}
                />
            </Table>
        </List>
    );
};
