import { Edit, useForm, useSelect } from "@refinedev/antd";
import { Form, Input, InputNumber, Select } from "antd";

export const WalletEdit = () => {
    const { formProps, saveButtonProps, queryResult } = useForm();

    const { selectProps: userSelectProps } = useSelect({
        resource: "users",
        optionLabel: "name",
        optionValue: "id",
        defaultValue: queryResult?.data?.data?.user_id,
    });

    return (
        <Edit saveButtonProps={saveButtonProps}>
            <Form {...formProps} layout="vertical">
                <Form.Item
                    label="Name"
                    name="name"
                    rules={[{ required: true, message: "Wallet name is required" }]}
                >
                    <Input />
                </Form.Item>
                <Form.Item
                    label="Balance"
                    name="balance"
                    rules={[{ required: true, message: "Balance is required" }]}
                >
                    <InputNumber
                        style={{ width: "100%" }}
                        formatter={(value) => `Rp ${value}`.replace(/\B(?=(\d{3})+(?!\d))/g, ",")}
                        parser={(value) => value!.replace(/Rp\s?|(,*)/g, "")}
                    />
                </Form.Item>
                <Form.Item
                    label="User"
                    name="user_id"
                    rules={[{ required: true, message: "Please select a user" }]}
                >
                    <Select {...userSelectProps} placeholder="Select user" />
                </Form.Item>
            </Form>
        </Edit>
    );
};
