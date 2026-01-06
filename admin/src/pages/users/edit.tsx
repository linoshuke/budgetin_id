import { Edit, useForm } from "@refinedev/antd";
import { Form, Input } from "antd";

export const UserEdit = () => {
    const { formProps, saveButtonProps } = useForm();

    return (
        <Edit saveButtonProps={saveButtonProps}>
            <Form {...formProps} layout="vertical">
                <Form.Item
                    label="Name"
                    name="name"
                    rules={[{ required: true, message: "Name is required" }]}
                >
                    <Input />
                </Form.Item>
                <Form.Item
                    label="Email"
                    name="email"
                    rules={[
                        { required: true, message: "Email is required" },
                        { type: "email", message: "Invalid email format" },
                    ]}
                >
                    <Input />
                </Form.Item>
                <Form.Item
                    label="New Password"
                    name="password"
                    rules={[
                        { min: 8, message: "Password must be at least 8 characters" },
                    ]}
                    extra="Leave empty to keep current password"
                >
                    <Input.Password />
                </Form.Item>
                <Form.Item
                    label="Confirm New Password"
                    name="password_confirmation"
                    dependencies={["password"]}
                    rules={[
                        ({ getFieldValue }) => ({
                            validator(_, value) {
                                if (!getFieldValue("password") || getFieldValue("password") === value) {
                                    return Promise.resolve();
                                }
                                return Promise.reject(new Error("Passwords do not match"));
                            },
                        }),
                    ]}
                >
                    <Input.Password />
                </Form.Item>
            </Form>
        </Edit>
    );
};
