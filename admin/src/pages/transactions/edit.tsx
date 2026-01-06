import { Edit, useForm, useSelect } from "@refinedev/antd";
import { Form, Input, InputNumber, Select, DatePicker } from "antd";
import dayjs from "dayjs";

export const TransactionEdit = () => {
    const { formProps, saveButtonProps, queryResult } = useForm();

    const { selectProps: walletSelectProps } = useSelect({
        resource: "wallets",
        optionLabel: "name",
        optionValue: "id",
        defaultValue: queryResult?.data?.data?.wallet_id,
    });

    // Transform date for DatePicker
    const initialValues = queryResult?.data?.data
        ? {
            ...queryResult.data.data,
            date: queryResult.data.data.date ? dayjs(queryResult.data.data.date) : undefined,
        }
        : undefined;

    return (
        <Edit saveButtonProps={saveButtonProps}>
            <Form {...formProps} layout="vertical" initialValues={initialValues}>
                <Form.Item
                    label="Description"
                    name="description"
                    rules={[{ required: true, message: "Description is required" }]}
                >
                    <Input />
                </Form.Item>
                <Form.Item
                    label="Type"
                    name="type"
                    rules={[{ required: true, message: "Type is required" }]}
                >
                    <Select>
                        <Select.Option value="income">Income</Select.Option>
                        <Select.Option value="expense">Expense</Select.Option>
                    </Select>
                </Form.Item>
                <Form.Item
                    label="Amount"
                    name="amount"
                    rules={[
                        { required: true, message: "Amount is required" },
                        { type: "number", min: 0.01, message: "Amount must be positive" },
                    ]}
                >
                    <InputNumber
                        style={{ width: "100%" }}
                        formatter={(value) => `Rp ${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}
                        parser={(value) => value!.replace(/Rp\s?|(,*)/g, "")}
                    />
                </Form.Item>
                <Form.Item
                    label="Wallet"
                    name="wallet_id"
                    rules={[{ required: true, message: "Please select a wallet" }]}
                >
                    <Select {...walletSelectProps} placeholder="Select wallet" />
                </Form.Item>
                <Form.Item
                    label="Date"
                    name="date"
                    rules={[{ required: true, message: "Date is required" }]}
                >
                    <DatePicker style={{ width: "100%" }} />
                </Form.Item>
                <Form.Item label="Category" name="category">
                    <Input placeholder="e.g., Food, Transport, Salary" />
                </Form.Item>
            </Form>
        </Edit>
    );
};
